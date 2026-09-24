import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';

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

  bool offline(Object error) =>
      error is TimeoutException || isRetryableOfflineFailure(error);
  Future<void> identify() async {
    _session ??= client.authenticationChanges.listen((_) {
      _owner = null;
      _epoch++;
    });
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

  Future<List<Map<String, dynamic>>> options() async =>
      (await read('request_options', {'company': company}) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  /// Choices for User, Department and Item Table fields ([fieldType]: `User`,
  /// `Department`, `Item`, or `UOM` with [itemCode]), from the ERPNext masters.
  Future<List<Map<String, dynamic>>> fieldOptions(String fieldType,
          {String txt = '', String? itemCode}) async =>
      (await read('request_field_options', {
        'company': company,
        'field_type': fieldType,
        'txt': txt,
        if (itemCode != null) 'item_code': itemCode,
      }) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
  Future<void> create(Map<String, dynamic> data, String requestId) async {
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
          status: LocalSyncStatus.pendingSync,
          payload: {'scope': _scope, 'data': payload});
    }
    await sync();
  }

  Future<void> sync({bool retry = false}) =>
      _sync ??= _replay(retry).whenComplete(() => _sync = null);
  Future<void> _replay(bool retry) async {
    await identify();
    final epoch = _epoch;
    for (final row in await pending()) {
      if (epoch != _epoch || !client.isAuthenticated) return;
      if (row.status == LocalSyncStatus.syncFailed && !retry) continue;
      try {
        final result = await remote('create_request',
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
    await sync();
    List<Map<String, dynamic>> rows;
    try {
      rows = (await read('list_my_requests', {'company': company}) as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (error) {
      if (!offline(error)) rethrow;
      rows = [];
    }
    for (final item in await store.list(entityType: 'generic_request_outbox')) {
      if (item.payload['scope'] != _scope) continue;
      if (item.status == LocalSyncStatus.synced) {
        final result = Map<String, dynamic>.from(item.payload['result'] as Map);
        if (!rows.any((row) => row['name'] == result['name'])) rows.insert(0, result);
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
        'pending_sync': true
      };
    }
    return Map<String, dynamic>.from(
        await read('get_request', {'name': name}) as Map);
  }
}
