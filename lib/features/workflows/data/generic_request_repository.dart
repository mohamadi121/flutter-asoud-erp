import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import 'offline_preview_data.dart';

/// Durable, user/server/company-scoped requests. Authorization failures never
/// fall back to cache and failed mutations are retained for explicit retry.
class GenericRequestRepository {
  GenericRequestRepository(this.client, this.company, {LocalRecordStore? store})
      : store = store ?? LocalDatabaseStore.instance;
  final FrappeApiClient client;
  final String company;
  final LocalRecordStore store;
  String? _owner;
  int _epoch = 0;
  StreamSubscription<bool>? _session;
  Future<void>? _sync;
  String get _server => client is FrappeClient
      ? (client as FrappeClient).serverIdentity
      : 'test-client';
  String get _scope => jsonEncode([_server, _owner, company]);
  String key(String action) =>
      'generic-request:${Uri.encodeComponent(_scope)}:$action';
  static String requestId() =>
      'request-${List.generate(20, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  void dispose() {
    _session?.cancel();
    _epoch++;
    _owner = null;
  }

  /// The offline preview (no session): request types, masters and submitted
  /// requests live on this device only and are never sent to a server.
  bool get isLocal => AppConfig.offlineDemoMode && !client.isAuthenticated;

  bool offline(Object error) =>
      error is TimeoutException ||
      isRetryableOfflineFailure(error) ||
      isQueuedOffline(error);
  Future<void> identify() async {
    _session ??= client.authenticationChanges.listen((_) {
      _owner = null;
      _epoch++;
    });
    if (isLocal) {
      _owner = 'offline-preview';
      return;
    }
    final epoch = _epoch;
    final user = await client.getCurrentUser();
    if (!client.isAuthenticated || epoch != _epoch) {
      throw StateError('نشست کاربر تغییر کرده است.');
    }
    _owner = user.userId;
  }

  Future<dynamic> remote(String method, Map<String, dynamic> data) => client
      .callAsoudMethod('asoud_erp.api.v1.workflow_request.$method', data: data)
      .timeout(const Duration(seconds: 20));
  Future<List<LocalRecord>> pending() async =>
      (await store.list(entityType: 'generic_request_outbox'))
          .where((row) =>
              row.payload['scope'] == _scope &&
              row.status != LocalSyncStatus.synced)
          .toList();
  Future<dynamic> read(String method, Map<String, dynamic> data) async {
    await identify();
    final epoch = _epoch, id = key('$method:${jsonEncode(data)}');
    try {
      final result = await remote(method, data);
      if (epoch != _epoch || !client.isAuthenticated) {
        throw StateError('نشست تغییر کرده است.');
      }
      await store.save(
          id: id,
          entityType: 'generic_request_cache',
          payload: {'value': result});
      return result;
    } catch (error) {
      if (!offline(error) || epoch != _epoch || !client.isAuthenticated) {
        rethrow;
      }
      final cached = await store.get(id);
      if (cached == null) rethrow;
      return cached.payload['value'];
    }
  }

  Future<List<Map<String, dynamic>>> options() async => isLocal
      ? offlineRequestTypes()
      : (await read('request_options', {'company': company}) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  /// Choices for User, Department and Item Table fields ([fieldType]: `User`,
  /// `Department`, `Item`, or `UOM` with [itemCode]), from the ERPNext masters.
  Future<List<Map<String, dynamic>>> fieldOptions(String fieldType,
          {String txt = '', String? itemCode}) async =>
      isLocal
          ? offlineFieldOptions(fieldType, txt: txt, itemCode: itemCode)
          : (await read('request_field_options', {
              'company': company,
              'field_type': fieldType,
              'txt': txt,
              if (itemCode != null) 'item_code': itemCode,
            }) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();

  /// Queues the request and syncs it; returns the server's request when it
  /// was accepted now, or null while it waits on this device. In the offline
  /// preview it returns the local request, which never syncs.
  Future<Map<String, dynamic>?> create(
      Map<String, dynamic> data, String requestId) async {
    await identify();
    final payload = {...data, 'company': company, 'request_id': requestId};
    final id = key(requestId);
    final existing = await store.get(id);
    if (existing != null &&
        jsonEncode(existing.payload['data']) != jsonEncode(payload)) {
      throw StateError(
          'این درخواست قبلاً ثبت شده؛ ابتدا وضعیت همگام‌سازی آن را بررسی کنید.');
    }
    if (existing == null) {
      await store.save(
          id: id,
          entityType: 'generic_request_outbox',
          status:
              isLocal ? LocalSyncStatus.localOnly : LocalSyncStatus.pendingSync,
          payload: {'scope': _scope, 'data': payload});
    }
    if (isLocal) return detail(id);
    await sync();
    final row = await store.get(id);
    final result = row?.payload['result'];
    return row?.status == LocalSyncStatus.synced && result is Map
        ? Map<String, dynamic>.from(result)
        : null;
  }

  /// Edits a request until it has been reviewed (server enforced).
  Future<Map<String, dynamic>> update(
      String name, String subject, Map<String, dynamic> values) async {
    await identify();
    final result = await remote(
        'update_request', {'name': name, 'subject': subject, 'values': values});
    return Map<String, dynamic>.from(result as Map);
  }

  /// Withdraws a request that is still in progress.
  Future<Map<String, dynamic>> cancel(String name, {String reason = ''}) async {
    await identify();
    final result =
        await remote('cancel_request', {'name': name, 'reason': reason});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> _sendCreate(Map<String, dynamic> data) async {
    // Single queue path: the outbox row above is the queued mutation. The
    // replay sends the mutation itself over the raw transport so the shared
    // queue does not stage a second row for the same logical request. The
    // `request_id` key keeps the send idempotent server-side.
    final response = await client
        .callMethod('asoud_erp.api.v1.workflow_request.create_request',
            data: data)
        .timeout(const Duration(seconds: 20));
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

  Future<void> sync({bool retry = false}) =>
      _sync ??= _replay(retry).whenComplete(() => _sync = null);
  Future<void> _replay(bool retry) async {
    await identify();
    final epoch = _epoch;
    for (final row in await pending()) {
      if (epoch != _epoch || !client.isAuthenticated) return;
      if (row.status == LocalSyncStatus.syncFailed && !retry) continue;
      if (row.status == LocalSyncStatus.localOnly) continue;
      try {
        final result = await _sendCreate(
            Map<String, dynamic>.from(row.payload['data'] as Map));
        if (epoch != _epoch || !client.isAuthenticated) return;
        await store.save(
            id: row.id,
            entityType: row.entityType,
            status: LocalSyncStatus.synced,
            payload: {...row.payload, 'result': result});
        await store.save(
            id: key('get_request:${jsonEncode({'name': result['name']})}'),
            entityType: 'generic_request_cache',
            payload: {'value': result});
      } catch (error) {
        if (epoch != _epoch || !client.isAuthenticated) return;
        if (offline(error)) return;
        await store.setStatus(row.id, LocalSyncStatus.syncFailed,
            error: error.toString());
      }
    }
  }

  Future<List<Map<String, dynamic>>> list() async {
    List<Map<String, dynamic>> rows = [];
    if (isLocal) {
      await identify();
    } else {
      await sync();
      try {
        rows = (await read('list_my_requests', {'company': company}) as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      } catch (error) {
        if (!offline(error)) rethrow;
      }
    }
    for (final item in await store.list(entityType: 'generic_request_outbox')) {
      if (item.payload['scope'] != _scope) continue;
      if (item.status == LocalSyncStatus.synced) {
        final result = Map<String, dynamic>.from(item.payload['result'] as Map);
        if (!rows.any((row) => row['name'] == result['name'])) {
          rows.insert(0, result);
        }
        continue;
      }
      final data = item.payload['data'] as Map;
      rows.insert(0, {
        ...Map<String, dynamic>.from(data),
        'name': item.id,
        'request_type': data['workflow_definition'],
        'status': item.status == LocalSyncStatus.syncFailed
            ? 'نیازمند بررسی'
            : 'در انتظار همگام‌سازی',
        'pending_sync': true,
        'local_preview': item.status == LocalSyncStatus.localOnly,
        'creation': item.createdAt.toIso8601String(),
        'error': item.lastError
      });
    }
    return rows;
  }

  Future<Map<String, dynamic>> detail(String name) async {
    await identify();
    if (name.startsWith('generic-request:')) {
      final item = await store.get(name);
      if (item == null || item.payload['scope'] != _scope) {
        throw StateError('دسترسی مجاز نیست.');
      }
      return {
        ...Map<String, dynamic>.from(item.payload['data'] as Map),
        'name': name,
        'status': item.status.name,
        'error': item.lastError,
        'pending_sync': true,
        'local_preview': item.status == LocalSyncStatus.localOnly,
        'creation': item.createdAt.toIso8601String(),
        'local_number':
            'LOCAL-${item.createdAt.millisecondsSinceEpoch.toString().substring(7)}',
      };
    }
    return Map<String, dynamic>.from(
        await read('get_request', {'name': name}) as Map);
  }
}
