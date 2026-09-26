import 'dart:async';
import 'dart:convert';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../domain/organization_chart.dart';

class OrganizationSnapshot {
  const OrganizationSnapshot(this.rows, this.revision, this.pending,
      {this.server, this.rejected = false, this.warnings = const []});
  final List<OrgPosition> rows;
  final int revision;
  final bool pending, rejected;
  final OrganizationSnapshot? server;
  final List<String> warnings;
}

class OrganizationEmployee {
  const OrganizationEmployee(this.id, this.displayName);
  final String id, displayName;
}

class OrganizationRepository {
  OrganizationRepository(this.client, {LocalRecordStore? local})
      : local = local ?? LocalDatabaseStore.instance {
    _session = client.authenticationChanges.listen((_) => _epoch++);
  }
  final FrappeApiClient client;
  final LocalRecordStore local;
  late final StreamSubscription<bool> _session;
  int _epoch = 0;
  Stream<bool> get authenticationChanges => client.authenticationChanges;
  Future<void> dispose() async {
    _epoch++;
    await _session.cancel();
  }

  Future<(String, int)> _scope(String company, {bool write = false}) async {
    final epoch = _epoch;
    // Allow the client's bounded transport to reach its authenticated offline
    // fallback; a shorter outer timeout would skip that fallback entirely.
    final user =
        await client.getCurrentUser().timeout(const Duration(seconds: 40));
    _check(epoch);
    final allowed = {'System Manager', 'HR Manager', if (!write) 'HR User'};
    if (user.userId.isEmpty || !user.roles.any(allowed.contains)) {
      throw const ApiException(
          kind: ApiFailureKind.forbidden,
          message: 'دسترسی به ساختار سازمانی مجاز نیست.');
    }
    final server = client is FrappeClient
        ? (client as FrappeClient).serverIdentity
        : 'injected-client-${identityHashCode(client)}';
    // Never adopt ownerless legacy cache entries.
    return (
      'org-v2:${Uri.encodeComponent(jsonEncode([
            server,
            user.userId,
            company
          ]))}',
      epoch
    );
  }

  void _check(int epoch) {
    if (_epoch != epoch || !client.isAuthenticated) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message: 'نشست تغییر کرده است؛ دوباره وارد شوید.');
    }
  }

  OrganizationSnapshot decode(Map<String, dynamic> data, bool pending,
      {OrganizationSnapshot? server, bool rejected = false}) {
    if (data['rows'] is! List || data['revision'] is! num) {
      throw const ApiException.protocol();
    }
    final rows = (data['rows'] as List)
        .map((e) => OrgPosition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    validateOrganization(rows);
    return OrganizationSnapshot(
        rows, (data['revision'] as num).toInt(), pending,
        server: server,
        rejected: rejected,
        warnings: (data['warnings'] as List? ?? const [])
            .map((e) => e.toString())
            .toList());
  }

  Future<Map<String, dynamic>> _call(
      String method, Map<String, dynamic> data) async {
    // Explicit draft retry only; never enqueue through the generic offline writer.
    final response = await client
        .callMethod('asoud_erp.api.v1.organization.$method', data: data)
        .timeout(const Duration(seconds: 15));
    final envelope = response['message'];
    if (envelope is! Map ||
        envelope['meta'] is! Map ||
        (envelope['meta'] as Map)['api_version'] != 'v1') {
      throw const ApiException.protocol();
    }
    return AsoudApiResponse<Map<String, dynamic>>.parse(
        Map<String, dynamic>.from(envelope),
        (value) => Map<String, dynamic>.from(value as Map)).data;
  }

  Future<OrganizationSnapshot> load(String company) async {
    final (key, epoch) = await _scope(company);
    final cached = await local.get(key);
    final draft = await local.get('$key:draft');
    _check(epoch);
    late final OrganizationSnapshot server;
    try {
      final data = await _call('get_chart', {'company': company});
      _check(epoch);
      server = decode(data, false);
      await local.save(
          id: key,
          entityType: 'organization_chart',
          payload: data,
          status: LocalSyncStatus.synced);
    } catch (e) {
      _check(epoch);
      if (e is! TimeoutException && !isRetryableOfflineFailure(e)) rethrow;
      if (draft != null)
        return decode(draft.payload, true,
            rejected: draft.status == LocalSyncStatus.syncFailed);
      return cached == null
          ? const OrganizationSnapshot([], 0, false)
          : decode(cached.payload, false);
    }
    _check(epoch);
    return draft == null
        ? server
        : decode(draft.payload, true,
            server: server,
            rejected: draft.status == LocalSyncStatus.syncFailed);
  }

  Future<List<OrganizationEmployee>> employees(String company) async {
    final (key, epoch) = await _scope(company);
    Map<String, dynamic> data;
    try {
      data = await _call('list_employees', {'company': company});
      _check(epoch);
      await local.save(
          id: '$key:people',
          entityType: 'organization_people',
          payload: data,
          status: LocalSyncStatus.synced);
    } catch (e) {
      _check(epoch);
      if (e is! TimeoutException && !isRetryableOfflineFailure(e)) rethrow;
      final cached = await local.get('$key:people');
      if (cached == null) rethrow;
      data = cached.payload;
    }
    _check(epoch);
    return (data['employees'] as List)
        .map((e) => OrganizationEmployee(
            e['id'] as String, e['display_name'] as String))
        .toList();
  }

  Future<OrganizationSnapshot> save(
      String company, List<OrgPosition> rows, int revision) async {
    validateOrganization(rows);
    final (key, epoch) = await _scope(company, write: true);
    final payload = {
      'company': company,
      'rows': rows.map((e) => e.toJson()).toList(),
      'revision': revision
    };
    await local.save(
        id: '$key:draft',
        entityType: 'organization_draft',
        payload: payload,
        status: LocalSyncStatus.pendingSync);
    _check(epoch);
    try {
      final data = await _call('save_chart', {'payload': payload});
      _check(epoch);
      final snapshot = decode(data, false);
      await local.save(
          id: key,
          entityType: 'organization_chart',
          payload: data,
          status: LocalSyncStatus.synced);
      await local.delete('$key:draft');
      _check(epoch);
      return snapshot;
    } catch (e) {
      _check(epoch);
      if (e is TimeoutException || isRetryableOfflineFailure(e)) {
        return OrganizationSnapshot(rows, revision, true);
      }
      await local.setStatus('$key:draft', LocalSyncStatus.syncFailed,
          error: e is ApiException ? e.message : 'ذخیره توسط سرور تأیید نشد.');
      rethrow;
    }
  }

  // Called only after the user reviews both versions. The rejected draft is
  // archived before switching; adopting a revision does not itself send a write.
  Future<OrganizationSnapshot> resolve(
      String company, OrganizationSnapshot draft,
      {required bool useServer}) async {
    final server = draft.server;
    if (server == null) throw StateError('ابتدا نسخه سرور را بازخوانی کنید.');
    final (key, epoch) = await _scope(company, write: true);
    final archived = {
      'rows': draft.rows.map((e) => e.toJson()).toList(),
      'revision': draft.revision,
      'company': company
    };
    await local.save(
        id: '$key:archive:${DateTime.now().microsecondsSinceEpoch}',
        entityType: 'organization_draft_archive',
        payload: archived,
        status: LocalSyncStatus.localOnly);
    _check(epoch);
    if (useServer) {
      await local.delete('$key:draft');
      return server;
    }
    await local.save(
        id: '$key:draft',
        entityType: 'organization_draft',
        payload: {...archived, 'revision': server.revision},
        status: LocalSyncStatus.pendingSync);
    _check(epoch);
    return OrganizationSnapshot(draft.rows, server.revision, true,
        server: server);
  }
}
