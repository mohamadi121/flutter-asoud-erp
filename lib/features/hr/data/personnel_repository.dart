import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/offline_failure.dart';
import '../../../core/config/app_config.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../domain/personnel_record.dart';

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}

const financialPersonnelFields = {
  'base_salary',
  'housing_allowance',
  'transport_allowance',
  'other_allowances',
  'deductions',
  'net_salary'
};

const personnelFields = [
  'display_name',
  'national_id',
  'birth_date',
  'employee_gender',
  'father_name',
  'mobile',
  'phone',
  'email',
  'province',
  'city',
  'address_line',
  'postal_code',
  'date_of_joining',
  'job_title',
  'department',
  'employment_type',
  'base_salary',
  'housing_allowance',
  'transport_allowance',
  'other_allowances',
  'deductions',
  'net_salary'
];

class PersonnelRepository {
  PersonnelRepository(this.client, {LocalRecordStore? local})
      : local = local ?? LocalDatabaseStore.instance;
  final FrappeApiClient client;
  final LocalRecordStore local;
  String? _company;
  String? _user;
  bool _canHr = false;
  String get _server => client is FrappeClient
      ? (client as FrappeClient).serverIdentity
      : 'injected-client';
  StreamSubscription<bool>? _session;
  int _epoch = 0;
  Future<void>? _sync;
  void dispose() {
    _session?.cancel();
    _session = null;
    _user = null;
    _epoch++;
  }

  bool _offline(Object error) =>
      error is TimeoutException || isRetryableOfflineFailure(error);

  Future<void> _identify() async {
    _session ??= client.authenticationChanges.listen((_) {
      _user = null;
      _epoch++;
    });
    final epoch = _epoch;
    try {
      final user =
          await client.getCurrentUser().timeout(const Duration(seconds: 12));
      if (epoch != _epoch || !client.isAuthenticated) {
        throw StateError('نشست کاربر تغییر کرده است');
      }
      _user = user.userId;
      _canHr = user.roles
          .any((role) => role == 'HR Manager' || role == 'System Manager');
    } catch (error) {
      if (client is FrappeClient || !_offline(error) || _user == null) rethrow;
    }
  }

  String _key(String action, Map<String, dynamic> data) =>
      'personnel-cache:${Uri.encodeComponent(jsonEncode([
            _user,
            _server,
            _company,
            action,
            data
          ]))}';

  Future<Map<String, dynamic>> _remote(
      String action, Map<String, dynamic> data) async {
    final response = await client
        .callMethod('asoud_erp.api.v1.personnel.$action', data: data)
        .timeout(const Duration(seconds: 12));
    final message = response['message'];
    if (message is! Map || message['data'] is! Map) {
      throw const FormatException('پاسخ نامعتبر منابع انسانی');
    }
    return Map<String, dynamic>.from(message['data'] as Map);
  }

  Future<void> syncPending() =>
      _sync ??= _replay().whenComplete(() => _sync = null);

  Future<void> synchronize(String company) async {
    _company = company;
    await syncPending();
  }

  String _requestId() =>
      'hr-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  Future<List<Map<String, dynamic>>> localImportCandidates() async {
    if (localDemo) return [];
    await _identify();
    return (await local.list(entityType: 'party_profile'))
        .where((r) =>
            '${r.payload['id']}'.startsWith('LOCAL-') &&
            r.payload['company'] == _company &&
            (r.payload['roles'] as List? ?? []).contains('employee'))
        .map((r) => _profile(r.payload))
        .toList();
  }

  /// Explicitly binds one local person to a server profile. Never matches names.
  /// Only records are imported; personal/financial master data is not overwritten.
  Future<void> importLocalRecords(String localId, String remoteId) async {
    if (localDemo) {
      throw StateError('برای انتقال سوابق، ورود به سرور لازم است.');
    }
    await _identify();
    final epoch = _epoch;
    final owner = _user;
    final source = await _demoPerson(localId);
    final target = await _remote('get_personnel', {'name': remoteId});
    if (epoch != _epoch || !client.isAuthenticated) {
      throw StateError('نشست تغییر کرده است');
    }
    if (target['can_edit'] != true ||
        (target['profile'] as Map)['company'] != _company) {
      throw StateError('دسترسی به پرونده مقصد مجاز نیست');
    }
    final key = 'personnel-import:${Uri.encodeComponent(jsonEncode([
          _server,
          _company,
          source.id
        ]))}';
    final existing = await local.get(key);
    if (existing != null &&
        (existing.payload['remote'] != remoteId ||
            existing.payload['owner'] != _user)) {
      throw StateError(
          'این پرسنل محلی قبلاً به پرونده یا حساب دیگری متصل شده است.');
    }
    final requests =
        Map<String, dynamic>.from(existing?.payload['requests'] as Map? ?? {});
    final records = (await local.list(entityType: 'personnel_demo_record'))
        .where((r) => r.payload['party'] == localId)
        .toList();
    for (final record in records) {
      validatePersonnelRecord(
          Map<String, dynamic>.from(record.payload['content'] as Map));
      requests.putIfAbsent(record.id, _requestId);
    }
    await local.save(id: key, entityType: 'personnel_import', payload: {
      'owner': owner,
      'server': _server,
      'company': _company,
      'remote': remoteId,
      'source': localId,
      'requests': requests,
    });
    for (final record in records) {
      if (epoch != _epoch || !client.isAuthenticated) {
        throw StateError('نشست تغییر کرده است');
      }
      final id = 'personnel-import-record:${requests[record.id]}';
      if (await local.get(id) != null) continue;
      await local.save(
          id: id,
          entityType: 'personnel_outbox',
          status: LocalSyncStatus.pendingSync,
          payload: {
            'owner': owner,
            'server': _server,
            'company': _company,
            'action': 'add_record',
            'data': {
              'name': remoteId,
              'payload': record.payload['content'],
              'request_id': requests[record.id]
            }
          });
    }
    await syncPending();
  }

  Future<void> retryFailed(String personId) async {
    await _identify();
    final target = await _remote('get_personnel', {'name': personId});
    if (target['can_edit'] != true ||
        (target['profile'] as Map)['company'] != _company) {
      throw StateError('دسترسی به پرونده مجاز نیست');
    }
    for (final item in await _pending()) {
      if (item.status == LocalSyncStatus.syncFailed &&
          (item.payload['data'] as Map)['name'] == personId) {
        await local.setStatus(item.id, LocalSyncStatus.pendingSync);
      }
    }
    await syncPending();
  }

  Future<void> _replay() async {
    if (localDemo) return;
    await _identify();
    final owner = _user;
    final epoch = _epoch;
    final pending = (await local.list(
            entityType: 'personnel_outbox',
            statuses: {
          LocalSyncStatus.pendingSync,
          LocalSyncStatus.syncFailed
        }))
        .where((r) =>
            r.payload['owner'] == owner &&
            r.payload['server'] == _server &&
            r.payload['company'] == _company)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final item in pending) {
      if (_epoch != epoch || !client.isAuthenticated) return;
      if (item.status == LocalSyncStatus.syncFailed) return;
      try {
        final response = await _remote(item.payload['action'] as String,
            Map<String, dynamic>.from(item.payload['data'] as Map));
        if (item.payload['action'] == 'update_personnel') {
          await _sharedProfile(response, LocalSyncStatus.synced);
        }
        if (item.payload['action'] == 'update_record') {
          await local.save(
              id: _key('get_record',
                  {'name': (item.payload['data'] as Map)['record_name']}),
              entityType: 'personnel_cache',
              payload: response,
              status: LocalSyncStatus.synced);
        }
        await local.setStatus(item.id, LocalSyncStatus.synced);
      } catch (error) {
        if (_offline(error)) return;
        await local.setStatus(item.id, LocalSyncStatus.syncFailed,
            error: error.toString());
        // Do not replay subsequent edits across a rejected revision/permission boundary.
        return;
      }
    }
  }

  bool get localDemo => AppConfig.offlineDemoMode && !client.isAuthenticated;

  Future<void> _sharedProfile(
      Map<String, dynamic> detail, LocalSyncStatus status) async {
    final profile = detail['profile'];
    if (profile is! Map || profile['id'] == null) return;
    final person =
        await local.get('party:${Uri.encodeComponent('${profile['id']}')}');
    if (person == null || person.payload['company'] != _company) return;
    await local.save(
        id: person.id,
        entityType: person.entityType,
        status: status,
        payload: {
          for (final entry in person.payload.entries)
            if (!financialPersonnelFields.contains(entry.key)) entry.key: entry.value,
          for (final field in personnelFields
              .where((field) => !financialPersonnelFields.contains(field)))
            if (profile.containsKey(field))
              (field == 'address_line' ? 'address' : field): profile[field],
        });
  }

  Future<List<LocalRecord>> _pending() async =>
      (await local.list(entityType: 'personnel_outbox', statuses: {
        LocalSyncStatus.pendingSync,
        LocalSyncStatus.syncFailed,
      }))
          .where((r) =>
              r.payload['owner'] == _user &&
              r.payload['server'] == _server &&
              r.payload['company'] == _company)
          .toList();

  Future<Map<String, dynamic>> _overlay(String action,
      Map<String, dynamic> data, Map<String, dynamic> result) async {
    final pending = await _pending();
    final merged = Map<String, dynamic>.from(result);
    if (pending.isNotEmpty) merged['pending_sync'] = true;
    if (pending.any((r) => r.status == LocalSyncStatus.syncFailed)) {
      merged['sync_failed'] = true;
    }
    for (final item in pending) {
      final input = item.payload['data'] as Map;
      if (action == 'get_personnel' && data['name'] == input['name']) {
        if (item.payload['action'] == 'update_personnel') {
          merged['profile'] = {
            ...(merged['profile'] as Map),
            ...(input['values'] as Map)
          };
        } else {
          final content = input['payload'] as Map;
          final recordId = item.payload['action'] == 'update_record'
              ? input['record_name']
              : item.id;
          merged['records'] = [
            ...(merged['records'] as List).where((r) => r['name'] != recordId),
            {
              'name': recordId,
              'kind': content['kind'],
              'title': content['title'],
              'record_date': content['date'],
              'pending_sync': true
            },
          ];
          if (content['kind'] == 'photo') {
            merged['profile'] = {
              ...(merged['profile'] as Map),
              'photo_record': recordId
            };
          }
        }
      }
      if (action == 'get_record' &&
          item.payload['action'] == 'update_record' &&
          data['name'] == input['record_name']) {
        merged.addAll(Map<String, dynamic>.from(input['payload'] as Map));
        merged['_can_edit'] = false;
        merged['pending_sync'] = true;
      }
      if (action == 'list_personnel' &&
          item.payload['action'] == 'update_personnel') {
        merged['rows'] = (merged['rows'] as List)
            .map((row) => row['id'] == input['name']
                ? {...(row as Map), ...(input['values'] as Map)}
                : row)
            .toList();
      }
    }
    if (!_canHr && merged['profile'] is Map) {
      merged['profile'] = Map<String, dynamic>.from(merged['profile'] as Map)
        ..removeWhere((key, _) => financialPersonnelFields.contains(key));
    }
    return merged;
  }

  Future<Map<String, dynamic>> call(
      String action, Map<String, dynamic> data) async {
    if (localDemo) return _demo(action, data);
    await _identify();
    final epoch = _epoch;
    final cacheKey = _key(action, data);
    final read = action.startsWith('get_') || action == 'list_personnel';
    if (action == 'get_record' &&
        ('${data['name']}'.startsWith('personnel-outbox:') ||
            '${data['name']}'.startsWith('personnel-import-record:'))) {
      final item = await local.get('${data['name']}');
      if (item == null ||
          item.payload['owner'] != _user ||
          item.payload['server'] != _server ||
          item.payload['company'] != _company) {
        throw StateError('دسترسی به سابقه مجاز نیست');
      }
      final input = item.payload['data'] as Map;
      // Revalidate access online, or require this session's already-authorized cache offline.
      await call('get_personnel', {'name': input['name']});
      return Map<String, dynamic>.from(input['payload'] as Map);
    }
    if (action == 'update_personnel' &&
        (await _pending()).any((r) =>
            r.payload['action'] == action &&
            (r.payload['data'] as Map)['name'] == data['name'])) {
      throw StateError(
          'ویرایش قبلی هنوز همگام نشده است؛ ابتدا وضعیت آن را بررسی کنید.');
    }
    if (action == 'update_record' &&
        (await _pending()).any((r) =>
            r.payload['action'] == action &&
            (r.payload['data'] as Map)['record_name'] == data['record_name'])) {
      throw StateError('ویرایش قبلی سابقه هنوز همگام نشده است.');
    }
    Map<String, dynamic> result;
    try {
      result = await _remote(action, data);
    } catch (error) {
      if (!_offline(error) || epoch != _epoch || !client.isAuthenticated) {
        rethrow;
      }
      if (read) {
        final cached = await local.get(cacheKey);
        if (cached == null) rethrow;
        return _overlay(action, data, {...cached.payload, 'offline': true});
      }
      final detail =
          await local.get(_key('get_personnel', {'name': data['name']}));
      if (detail == null || detail.payload['can_edit'] != true) rethrow;
      if (action == 'update_record') {
        final cachedRecord =
            await local.get(_key('get_record', {'name': data['record_name']}));
        if (cachedRecord == null ||
            cachedRecord.payload['_can_edit'] != true ||
            cachedRecord.payload['_revision'] != data['revision'] ||
            cachedRecord.payload['kind'] != (data['payload'] as Map)['kind']) {
          rethrow;
        }
        if (!(detail.payload['records'] as List)
            .any((r) => r['name'] == data['record_name'])) {
          rethrow;
        }
      }
      final pending = await local.list(
          entityType: 'personnel_outbox',
          statuses: {LocalSyncStatus.pendingSync, LocalSyncStatus.syncFailed});
      if (action == 'update_personnel' &&
          pending.any((r) =>
              r.payload['owner'] == _user &&
              r.payload['server'] == _server &&
              r.payload['company'] == _company &&
              (r.payload['data'] as Map)['name'] == data['name'] &&
              r.payload['action'] == action)) {
        throw StateError(
            'ویرایش قبلی هنوز همگام نشده است؛ ابتدا وضعیت آن را بررسی کنید.');
      }
      final id = 'personnel-outbox:${Uri.encodeComponent(jsonEncode([
            _user,
            _server,
            _company,
            data['request_id']
          ]))}';
      final existing = await local.get(id);
      if (existing != null && !_same(existing.payload['data'], data)) {
        throw StateError('شناسه درخواست تکراری با اطلاعات متفاوت');
      }
      await local.save(
          id: id,
          entityType: 'personnel_outbox',
          payload: {
            'owner': _user,
            'server': _server,
            'company': _company,
            'action': action,
            'data': data,
          },
          status: LocalSyncStatus.pendingSync);
      final content = Map<String, dynamic>.from(detail.payload);
      if (action == 'update_personnel') {
        content['profile'] = {
          ...(content['profile'] as Map),
          ...(data['values'] as Map)
        };
      } else {
        final payload = Map<String, dynamic>.from(data['payload'] as Map);
        final recordId =
            action == 'update_record' ? '${data['record_name']}' : id;
        await local.save(
            id: _key('get_record', {'name': recordId}),
            entityType: 'personnel_cache',
            payload: {...payload, '_can_edit': false, 'pending_sync': true},
            status: LocalSyncStatus.pendingSync);
        content['records'] = [
          ...(content['records'] as List).where((r) => r['name'] != recordId),
          {
            'name': recordId,
            'kind': payload['kind'],
            'title': payload['title'],
            'record_date': payload['date'],
            'pending_sync': true
          },
        ];
      }
      content['offline'] = true;
      content['pending_sync'] = true;
      await local.save(
          id: detail.id,
          entityType: 'personnel_cache',
          payload: content,
          status: LocalSyncStatus.pendingSync);
      if (action == 'update_personnel') {
        await _sharedProfile(content, LocalSyncStatus.pendingSync);
      }
      return action == 'update_personnel'
          ? content
          : {'id': id, 'pending_sync': true};
    }
    if (epoch != _epoch || !client.isAuthenticated) {
      throw StateError('نشست کاربر تغییر کرده است');
    }
    if (read) {
      await local.save(
          id: cacheKey,
          entityType: 'personnel_cache',
          payload: result,
          status: LocalSyncStatus.synced);
    }
    if (action == 'update_record') {
      await local.save(
          id: _key('get_record', {'name': data['record_name']}),
          entityType: 'personnel_cache',
          payload: result,
          status: LocalSyncStatus.synced);
    }
    if (action == 'update_personnel') {
      await _sharedProfile(result, LocalSyncStatus.synced);
    }
    return read ? _overlay(action, data, result) : result;
  }

  Future<Map<String, dynamic>> list(String company) async {
    _company = company;
    if (!localDemo) await syncPending();
    return call('list_personnel', {'company': company});
  }

  Future<Map<String, dynamic>> detail(String id) =>
      call('get_personnel', {'name': id});
  Future<Map<String, dynamic>> profileOptions(String id) =>
      call('get_profile_options', {'name': id});
  Future<Map<String, dynamic>> recordOptions(String id) =>
      call('get_record_options', {'name': id});
  Future<Map<String, dynamic>> record(String id) =>
      call('get_record', {'name': id});
  Future<Map<String, dynamic>> update(
          String id, Map<String, dynamic> values, String revision) =>
      call('update_personnel', {
        'name': id,
        'values': values,
        'revision': revision,
        'request_id': 'profile-${DateTime.now().microsecondsSinceEpoch}'
      });
  Future<void> add(
      String id, Map<String, dynamic> payload, String requestId) async {
    validatePersonnelRecord(payload);
    if (requestId.length < 8 || requestId.length > 100) {
      throw const FormatException('شناسه درخواست نامعتبر است');
    }
    await call('add_record',
        {'name': id, 'payload': payload, 'request_id': requestId});
  }

  Future<void> updateRecord(String personId, String recordId,
      Map<String, dynamic> payload, String revision, String requestId) async {
    validatePersonnelRecord(payload);
    if (revision.isEmpty || requestId.length < 8 || requestId.length > 100) {
      throw const FormatException('اطلاعات نسخه سابقه نامعتبر است.');
    }
    await call('update_record', {
      'name': personId,
      'record_name': recordId,
      'payload': payload,
      'revision': revision,
      'request_id': requestId
    });
  }

  Future<LocalRecord> _demoPerson(String id) async {
    final record = await local.get('party:${Uri.encodeComponent(id)}');
    if (!id.startsWith('LOCAL-') ||
        record == null ||
        record.payload['company'] != _company ||
        !(record.payload['roles'] as List? ?? []).contains('employee')) {
      throw StateError('فقط پرسنل محلی همین دفتر در حالت تست قابل دسترسی است.');
    }
    return record;
  }

  Map<String, dynamic> _profile(Map<String, dynamic> p) => {
        'id': p['id'],
        'company': p['company'],
        'disabled': p['disabled'] == true,
        for (final field in personnelFields)
          field: p[field == 'address_line' ? 'address' : field] ?? '',
      };
  Future<Map<String, dynamic>> _demo(
      String action, Map<String, dynamic> data) async {
    if (action == 'list_personnel') {
      final rows = (await local.list(entityType: 'party_profile')).where((r) =>
          '${r.payload['id']}'.startsWith('LOCAL-') &&
          r.payload['company'] == _company &&
          (r.payload['roles'] as List? ?? []).contains('employee'));
      return {
        'rows': await Future.wait(
            rows.map((r) async => await _withPhoto(_profile(r.payload)))),
        'can_edit': true
      };
    }
    if (action == 'get_record') {
      final record = await local.get('${data['name']}');
      if (record == null || record.entityType != 'personnel_demo_record') {
        throw StateError('سابقه یافت نشد');
      }
      await _demoPerson('${record.payload['party']}');
      final content =
          Map<String, dynamic>.from(record.payload['content'] as Map);
      final editable = !content.containsKey('_update') &&
          !content.containsKey('_record_update');
      content.remove('_update');
      content.remove('_record_update');
      return {
        ...content,
        '_id': record.id,
        '_revision': record.updatedAt.toIso8601String(),
        '_can_edit': editable
      };
    }
    final person = await _demoPerson('${data['name']}');
    if (action == 'get_personnel') {
      final records = (await local.list(entityType: 'personnel_demo_record'))
          .where((r) => r.payload['party'] == data['name']);
      return {
        'profile': await _withPhoto(_profile(person.payload)),
        'can_edit': true,
        'revision': person.updatedAt.toIso8601String(),
        'records': records
            .map((r) => {
                  'name': r.id,
                  'kind': (r.payload['content'] as Map)['kind'],
                  'title': (r.payload['content'] as Map)['title'],
                  'record_date': (r.payload['content'] as Map)['date']
                })
            .toList()
      };
    }
    if (action == 'update_personnel') {
      if (person.updatedAt.toIso8601String() != data['revision']) {
        throw StateError('پرونده تغییر کرده است');
      }
      final values = Map<String, dynamic>.from(data['values'] as Map);
      if (values.keys.any((key) => !personnelFields.contains(key))) {
        throw StateError('فیلد غیرمجاز');
      }
      await local.save(
          id: person.id,
          entityType: person.entityType,
          payload: {
            for (final entry in person.payload.entries)
            if (!financialPersonnelFields.contains(entry.key)) entry.key: entry.value,
            for (final e in values.entries)
              (e.key == 'address_line' ? 'address' : e.key): e.value,
          },
          status: LocalSyncStatus.localOnly);
      await local.save(
          id: 'personnel-demo:audit-${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'personnel_demo_record',
          payload: {
            'party': data['name'],
            'content': {
              'kind': 'history',
              'title': 'ویرایش اطلاعات پرسنلی',
              'date': DateTime.now().toIso8601String().substring(0, 10),
              'notes': values.keys.join('، '),
              '_update': true
            }
          },
          status: LocalSyncStatus.localOnly);
      return _demo('get_personnel', {'name': data['name']});
    }
    if (action == 'update_record') {
      final record = await local.get('${data['record_name']}');
      if (record == null ||
          record.entityType != 'personnel_demo_record' ||
          record.payload['party'] != data['name']) {
        throw StateError('سابقه متعلق به این پرسنل نیست.');
      }
      final previous = record.payload['content'] as Map;
      final next = Map<String, dynamic>.from(data['payload'] as Map);
      if (previous.containsKey('_update') ||
          previous.containsKey('_record_update') ||
          previous['kind'] != next['kind']) {
        throw StateError('ویرایش این سابقه مجاز نیست.');
      }
      final receiptId = 'personnel-demo-edit:${data['request_id']}';
      final receipt = await local.get(receiptId);
      if (receipt != null) {
        if (!_same(receipt.payload['request'], data)) {
          throw StateError('شناسه درخواست تکراری با اطلاعات متفاوت');
        }
        return _demo('get_record', {'name': record.id});
      }
      if (record.updatedAt.toIso8601String() != data['revision']) {
        throw StateError('سابقه تغییر کرده است؛ دوباره باز کنید.');
      }
      await local.save(
          id: record.id,
          entityType: record.entityType,
          payload: {...record.payload, 'content': next},
          status: LocalSyncStatus.localOnly);
      await local.save(
          id: receiptId,
          entityType: 'personnel_demo_record',
          payload: {
            'party': data['name'],
            'request': data,
            'content': {
              'kind': 'history',
              'title': 'ویرایش سابقه پرسنلی',
              'date': DateTime.now().toIso8601String().substring(0, 10),
              'notes': next['title'],
              '_record_update': true,
            }
          },
          status: LocalSyncStatus.localOnly);
      return _demo('get_record', {'name': record.id});
    }
    if (action == 'add_record') {
      final key = 'personnel-demo:${data['request_id']}';
      final existing = await local.get(key);
      if (existing != null) {
        if (existing.payload['party'] != data['name'] ||
            !_same(existing.payload['content'], data['payload'])) {
          throw StateError('شناسه درخواست تکراری با اطلاعات متفاوت');
        }
        return {'id': key};
      }
      await local.save(
          id: key,
          entityType: 'personnel_demo_record',
          payload: {'party': data['name'], 'content': data['payload']},
          status: LocalSyncStatus.localOnly);
      return {'id': key};
    }
    throw StateError('عملیات ناشناخته');
  }

  Future<Map<String, dynamic>> _withPhoto(Map<String, dynamic> profile) async {
    final records = (await local.list(entityType: 'personnel_demo_record'))
        .where((r) =>
            r.payload['party'] == profile['id'] &&
            (r.payload['content'] as Map)['kind'] == 'photo')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return {
      ...profile,
      'photo_record': records.isEmpty ? null : records.first.id
    };
  }
}
