import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../../request_templates/data/system_templates.dart';
import '../domain/entities/request_models.dart';
import 'demo/request_demo_data.dart';
import 'offline_preview_data.dart';
import 'request_demo_source.dart';

const _module = 'workflow_request';
const _cacheEntity = 'generic_request_cache';
const _commentEntity = 'generic_request_comment';
const _pendingCommentEntity = 'generic_request_comment_pending';

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

  /// Calls `asoud_erp.api.v1.<module>.<method>`. Mutation names go through the
  /// client's offline mutation queue and may throw `QueuedOfflineException`.
  Future<dynamic> remote(String method, Map<String, dynamic> data,
          {String module = _module}) =>
      client
          .callAsoudMethod('asoud_erp.api.v1.$module.$method', data: data)
          .timeout(const Duration(seconds: 20));

  /// This scope's outbox rows, oldest first: the replay and the list below must
  /// not depend on the store's own order.
  Future<List<LocalRecord>> _outbox() async =>
      (await store.list(entityType: 'generic_request_outbox'))
          .where((row) => row.payload['scope'] == _scope)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  Future<List<LocalRecord>> pending() async => (await _outbox())
      .where((row) => row.status != LocalSyncStatus.synced)
      .toList();

  /// A read-only call with a cache fallback while offline.
  Future<dynamic> read(String method, Map<String, dynamic> data,
      {String module = _module}) async {
    await identify();
    final epoch = _epoch,
        id = key(
            '${module == _module ? '' : '$module.'}$method:${jsonEncode(data)}');
    try {
      final result = await remote(method, data, module: module);
      if (epoch != _epoch || !client.isAuthenticated) {
        throw StateError('نشست تغییر کرده است.');
      }
      await store
          .save(id: id, entityType: _cacheEntity, payload: {'value': result});
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

  /// Like [read], but also returns the envelope's `meta` (totals, counts).
  /// It uses the raw transport, because `callAsoudMethod` drops the meta.
  Future<({dynamic data, Map<String, dynamic> meta})> _readEnvelope(
      String method, Map<String, dynamic> data) async {
    await identify();
    final epoch = _epoch, id = key('$method:${jsonEncode(data)}');
    try {
      final response = await client
          .callMethod('asoud_erp.api.v1.$_module.$method', data: data)
          .timeout(const Duration(seconds: 20));
      final envelope = response['message'];
      if (envelope is! Map ||
          envelope['meta'] is! Map ||
          (envelope['meta'] as Map)['api_version'] != 'v1') {
        throw const ApiException.protocol();
      }
      final parsed = AsoudApiResponse<Object?>.parse(
          Map<String, dynamic>.from(envelope), (value) => value);
      final meta = Map<String, dynamic>.from(envelope['meta'] as Map);
      if (epoch != _epoch || !client.isAuthenticated) {
        throw StateError('نشست تغییر کرده است.');
      }
      await store.save(
          id: id,
          entityType: _cacheEntity,
          payload: {'value': parsed.data, 'meta': meta});
      return (data: parsed.data, meta: meta);
    } catch (error) {
      if (!offline(error) || epoch != _epoch || !client.isAuthenticated) {
        rethrow;
      }
      final cached = await store.get(id);
      if (cached == null) rethrow;
      return (
        data: cached.payload['value'],
        meta: Map<String, dynamic>.from(cached.payload['meta'] as Map? ?? {})
      );
    }
  }

  Future<List<Map<String, dynamic>>> options() async {
    if (isLocal) return offlineRequestTypes();
    final items = (await read('request_options', {'company': company}) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    try {
      final active = await client.callAsoudMethod(
        'asoud_erp.api.v1.workflow.list_workflows',
        data: {
          if (company.trim().isNotEmpty) 'company': company,
          'status': 'Active',
        },
      );
      if (active is List) {
        final existingNames = items
            .map((r) => r['name']?.toString() ?? r['workflow_code']?.toString())
            .whereType<String>()
            .toSet();
        for (final row in active.whereType<Map>()) {
          final target = row['target_doctype']?.toString();
          if (target != null && target != 'ASOUD Workflow Request') continue;
          if (row['allow_user_submission'] == false) continue;
          final name = row['name']?.toString() ?? '';
          final code = row['workflow_code']?.toString() ?? name;
          if (existingNames.contains(name) || existingNames.contains(code)) {
            continue;
          }
          final templateKey = row['template_key']?.toString() ??
              (code.startsWith('SYS-PURCHASE')
                  ? 'purchase'
                  : code.startsWith('SYS-LEAVE')
                      ? 'leave'
                      : code.startsWith('SYS-SUPPLY')
                          ? 'supply'
                          : null);
          Map<String, dynamic>? systemType;
          if (templateKey != null) {
            try {
              systemType = systemRequestType(templateKey, company: company);
            } catch (_) {}
          }
          items.add({
            if (systemType != null) ...systemType,
            'name': name,
            'workflow_code': code,
            'workflow_title': row['workflow_title']?.toString() ??
                systemType?['workflow_title'] ??
                code,
            'short_title': row['short_title']?.toString() ??
                systemType?['short_title'] ??
                '',
            'icon_key': row['icon_key']?.toString() ??
                systemType?['icon_key'] ??
                'task',
            'color_hex': row['color_hex']?.toString() ??
                systemType?['color_hex'] ??
                '#1769F6',
            if (templateKey != null) 'template_key': templateKey,
            'fields': systemType?['fields'] ?? const [],
          });
          existingNames.add(name);
          existingNames.add(code);
        }
      }
    } catch (_) {}

    return items;
  }

  /// Choices for User, Department, Item Table and System Select fields
  /// ([fieldType]: `User`, `Department`, `Item`, `UOM` with [itemCode],
  /// `Cost Center`, `Project`, `Warehouse`, `Branch`, `Supplier`,
  /// `Leave Type`, `Delivery Location`), from the ERPNext masters. [scope]
  /// (`purchase` / `all`) applies to `Item`.
  Future<List<Map<String, dynamic>>> fieldOptions(String fieldType,
          {String txt = '', String? itemCode, String? scope}) async =>
      isLocal
          ? offlineFieldOptions(fieldType,
              txt: txt, itemCode: itemCode, scope: scope)
          : (await read('request_field_options', {
              'company': company,
              'field_type': fieldType,
              'txt': txt,
              if (itemCode != null) 'item_code': itemCode,
              if (scope != null) 'scope': scope,
            }) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();

  /// The Persian title of the request type [data] is created for, from the
  /// cached `request_options` (never from the network: the caller is saving a
  /// request that may have to wait for a connection).
  Future<String> _typeTitle(Map<String, dynamic> data) async {
    try {
      List<Map<String, dynamic>> types;
      if (isLocal) {
        types = await offlineRequestTypes();
      } else {
        final cached = await store
            .get(key('request_options:${jsonEncode({'company': company})}'));
        types = [
          for (final row in cached?.payload['value'] as List? ?? const [])
            if (row is Map) Map<String, dynamic>.from(row)
        ];
      }
      final templateKey = '${data['template_key'] ?? ''}';
      final type = types.where((row) {
        if (templateKey.isNotEmpty) return row['template_key'] == templateKey;
        return row['name'] == data['workflow_definition'];
      }).firstOrNull;
      return '${type?['workflow_title'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  /// Queues the request and syncs it; returns the server's request when it
  /// was accepted now, or null while it waits on this device. In the offline
  /// preview it returns the local request, which never syncs.
  ///
  /// [data] is exactly the `create_request` arguments (`template_key` or
  /// `workflow_definition`, `subject`, `values`, `attachments`, ...);
  /// `company` and `request_id` are added here. UI hints for the list live
  /// next to it in the outbox row (`payload['ui']`).
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
          payload: {
            'scope': _scope,
            'data': payload,
            'ui': {
              'template_key': '${data['template_key'] ?? ''}',
              'request_type_title': await _typeTitle(data),
              'subject': '${data['subject'] ?? ''}',
            },
          });
    }
    if (isLocal) return detail(id);
    await sync();
    final row = await store.get(id);
    final result = row?.payload['result'];
    return row?.status == LocalSyncStatus.synced && result is Map
        ? Map<String, dynamic>.from(result)
        : null;
  }

  /// Whether [name] is a built-in sample row of the offline preview.
  bool isSampleRequest(String name) =>
      isLocal &&
      [...demoRequests(), ...RequestDemoRegistry.requests()]
          .any((row) => row['name'] == name && row['is_sample'] == true);

  static const _sampleEditMessage =
      'درخواست نمایشی قابل ویرایش نیست؛ یک درخواست جدید ثبت کنید.';
  static const _sampleCancelMessage =
      'درخواست نمایشی قابل لغو نیست؛ یک درخواست جدید ثبت کنید.';
  static const _localMessage =
      'این درخواست فقط روی گوشی (پیش‌نمایش آفلاین) ذخیره شده و قابل تغییر نیست.';

  /// Edits a request until it has been reviewed (server enforced). New files
  /// ([attachments], each `{filename, content_base64, ref}`) are uploaded and
  /// File names in [removeAttachments] are deleted. While offline the write is
  /// queued and a `QueuedOfflineException` («ذخیره شد؛ پس از اتصال ارسال
  /// می‌شود») is thrown.
  Future<Map<String, dynamic>> update(
      String name, String subject, Map<String, dynamic> values,
      {List<Map<String, String>>? attachments,
      List<String>? removeAttachments}) async {
    if (isSampleRequest(name)) throw StateError(_sampleEditMessage);
    if (isLocal) throw StateError(_localMessage);
    await identify();
    final result = await remote('update_request', {
      'name': name,
      'subject': subject,
      'values': values,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
      if (removeAttachments != null && removeAttachments.isNotEmpty)
        'remove_attachments': removeAttachments,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Withdraws a request that is still in progress.
  Future<Map<String, dynamic>> cancel(String name, {String reason = ''}) async {
    if (isSampleRequest(name)) throw StateError(_sampleCancelMessage);
    if (isLocal) throw StateError(_localMessage);
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
            entityType: _cacheEntity,
            payload: {'value': result});
      } catch (error) {
        if (epoch != _epoch || !client.isAuthenticated) return;
        if (offline(error)) return;
        // The row keeps the server's readable message (`_server_messages`).
        await store.setStatus(row.id, LocalSyncStatus.syncFailed,
            error: offlineFailureMessage(error));
      }
    }
  }

  static String _localNumber(LocalRecord item) =>
      'LOCAL-${item.createdAt.millisecondsSinceEpoch.toString().substring(7)}';

  /// An outbox row as a list row: «در انتظار همگام‌سازی», «ذخیره روی گوشی» (the
  /// offline preview) or «نیازمند بررسی» when the server refused it.
  Map<String, dynamic> _outboxRow(LocalRecord item) {
    final data = Map<String, dynamic>.from(item.payload['data'] as Map);
    final ui = item.payload['ui'] is Map
        ? Map<String, dynamic>.from(item.payload['ui'] as Map)
        : <String, dynamic>{};
    final failed = item.status == LocalSyncStatus.syncFailed;
    final local = item.status == LocalSyncStatus.localOnly;
    final values = data['values'] is Map
        ? Map<String, dynamic>.from(data['values'] as Map)
        : <String, dynamic>{};
    final label = failed
        ? 'نیازمند بررسی'
        : local
            ? 'ذخیره روی گوشی'
            : 'در انتظار همگام‌سازی';
    final title = '${ui['request_type_title'] ?? ''}'.trim().isNotEmpty
        ? '${ui['request_type_title']}'
        : switch ('${ui['template_key'] ?? data['template_key'] ?? ''}') {
            'leave' => 'درخواست مرخصی',
            'purchase' => 'درخواست خرید کالا',
            'supply' => 'درخواست تأمین کالا / خدمت',
            _ => '${data['workflow_definition'] ?? ''}',
          };
    return {
      ...data,
      'name': item.id,
      'number': local ? _localNumber(item) : '—',
      if (local) 'local_number': _localNumber(item),
      'template_key': '${ui['template_key'] ?? data['template_key'] ?? ''}',
      'request_type': title.isNotEmpty ? title : data['workflow_definition'],
      'subject': '${data['subject'] ?? ui['subject'] ?? ''}'.trim().isNotEmpty
          ? '${data['subject'] ?? ui['subject'] ?? ''}'
          : title,
      'status': failed ? 'نیازمند بررسی' : 'در انتظار همگام‌سازی',
      'status_key': failed ? 'failed' : 'submitted',
      'status_label': label,
      'status_group': 'pending',
      'pending_sync': true,
      'local_preview': local,
      'creation': item.createdAt.toIso8601String(),
      'error': item.lastError,
      'item_count': [
        for (final value in values.values)
          if (value is List)
            for (final row in value)
              if (row is Map && row['item_code'] != null) row
      ].length,
      'attachment_count': (data['attachments'] as List?)?.length ?? 0,
      'summary': {
        for (final entry in values.entries)
          if (entry.value is! List && entry.value is! Map)
            entry.key: entry.value,
        'from_date': values['start_date'] ?? values['leave_date'],
        'to_date': values['end_date'] ?? values['leave_date'],
      },
    };
  }

  /// The tab counts and filter of list rows (shared by the outbox merge and
  /// the offline preview).
  static bool _matches(RequestSummary row,
      {String? templateKey,
      String statusGroup = 'all',
      String search = '',
      String? priority,
      String? dateFrom,
      String? dateTo,
      bool ignoreStatus = false}) {
    if (templateKey != null &&
        templateKey.isNotEmpty &&
        row.templateKey != templateKey) {
      return false;
    }
    if (!ignoreStatus &&
        statusGroup != 'all' &&
        row.statusGroup != statusGroup) {
      return false;
    }
    if (priority != null && priority.isNotEmpty && row.priority != priority) {
      return false;
    }
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        ![
          row.number,
          row.name,
          row.subject,
          row.requesterName,
          row.requestType,
        ].any((text) => text.toLowerCase().contains(needle))) {
      return false;
    }
    final created = DateTime.tryParse(row.creation);
    if (created != null) {
      final day = DateTime(created.year, created.month, created.day);
      final from = DateTime.tryParse(dateFrom ?? '');
      final to = DateTime.tryParse(dateTo ?? '');
      if (from != null && day.isBefore(from)) return false;
      if (to != null && day.isAfter(to)) return false;
    }
    return true;
  }

  static Map<String, int> _counts(Iterable<RequestSummary> rows) => {
        'all': rows.length,
        for (final group in const ['pending', 'approved', 'rejected'])
          group: rows.where((row) => row.statusGroup == group).length,
      };

  /// One page of the signed-in user's requests (§4.6), newest first. On the
  /// first page (offset 0) the durable outbox rows (waiting, failed or saved
  /// only on this device) come first. [statusGroup] is `all`, `pending`,
  /// `approved` or `rejected`; `counts` ignore it.
  Future<RequestListPage> listPage({
    String? templateKey,
    String statusGroup = 'all',
    String search = '',
    int offset = 0,
    int limit = 20,
    String? priority,
    String? dateFrom,
    String? dateTo,
  }) async {
    bool matches(RequestSummary row, {bool ignoreStatus = false}) =>
        _matches(row,
            templateKey: templateKey,
            statusGroup: statusGroup,
            search: search,
            priority: priority,
            dateFrom: dateFrom,
            dateTo: dateTo,
            ignoreStatus: ignoreStatus);
    if (isLocal) {
      await identify();
      // The user's own rows first (newest first; the outbox is oldest first),
      // then the built-in samples.
      final own = [
        for (final row in await _outbox())
          if (row.status != LocalSyncStatus.synced)
            RequestSummary.fromMap(_outboxRow(row))
      ].reversed;
      final rows = [
        ...own,
        for (final row in [
          ...RequestDemoRegistry.requests(),
          ...demoRequests()
        ])
          RequestSummary.fromMap(row)
      ];
      final visible = rows.where(matches).toList();
      return RequestListPage(
        items: visible.skip(offset).take(limit).toList(),
        total: visible.length,
        offset: offset,
        counts: _counts(rows.where((row) => matches(row, ignoreStatus: true))),
      );
    }
    await sync();
    var items = <RequestSummary>[];
    var total = 0, local = 0;
    var counts = <String, int>{
      'all': 0,
      'pending': 0,
      'approved': 0,
      'rejected': 0
    };
    try {
      final result = await _readEnvelope('list_my_requests', {
        'company': company,
        if (templateKey != null && templateKey.isNotEmpty)
          'template_key': templateKey,
        'status_group': statusGroup,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        'limit_start': offset,
        'limit_page_length': limit,
      });
      items = [
        for (final row in result.data as List? ?? const [])
          if (row is Map) RequestSummary.fromMap(row)
      ];
      total = (result.meta['total'] as num?)?.toInt() ?? items.length;
      final metaCounts = result.meta['counts'];
      if (metaCounts is Map) {
        counts = {
          for (final entry in metaCounts.entries)
            '${entry.key}': (entry.value as num?)?.toInt() ?? 0
        };
      }
    } catch (error) {
      if (!offline(error)) rethrow;
    }
    if (offset == 0) {
      final names = {for (final row in items) row.name};
      final added = <RequestSummary>[];
      for (final item in (await _outbox()).reversed) {
        if (item.status == LocalSyncStatus.synced) {
          final result = item.payload['result'];
          if (result is! Map || names.contains('${result['name']}')) continue;
          added.add(RequestSummary.fromMap(result));
        } else {
          added.add(RequestSummary.fromMap(_outboxRow(item)));
        }
      }
      final ofKind = added.where((row) => matches(row, ignoreStatus: true));
      counts = {
        for (final entry in counts.entries)
          entry.key: entry.value +
              ofKind
                  .where((row) =>
                      entry.key == 'all' || row.statusGroup == entry.key)
                  .length
      };
      final shown = added.where(matches).toList();
      items = [...shown, ...items];
      total += shown.length;
      local = shown.length;
    }
    return RequestListPage(
        items: items,
        total: total,
        offset: offset,
        counts: counts,
        localCount: local);
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
    for (final item in await _outbox()) {
      if (item.status == LocalSyncStatus.synced) {
        final result = Map<String, dynamic>.from(item.payload['result'] as Map);
        if (!rows.any((row) => row['name'] == result['name'])) {
          rows.insert(0, result);
        }
        continue;
      }
      rows.insert(0, _outboxRow(item));
    }
    if (isLocal && rows.isEmpty) {
      // Fresh preview: demo requests across every status so each flow can be
      // opened end to end. Once the user records their own requests, only
      // those are listed.
      rows = [...RequestDemoRegistry.requests(), ...demoRequests()];
    }
    return rows;
  }

  Future<Map<String, dynamic>> detail(String name) async {
    await identify();
    if (isLocal) {
      final sample = [...RequestDemoRegistry.requests(), ...demoRequests()]
          .where((row) => row['name'] == name && row['is_sample'] == true)
          .firstOrNull;
      if (sample != null) {
        final row = Map<String, dynamic>.from(sample);
        return {
          'can_edit': false,
          'can_cancel': false,
          'number': row['name'],
          ...row,
          'comment_count': (await comments(name)).length,
        };
      }
    }
    if (name.startsWith('generic-request:')) {
      final item = await store.get(name);
      if (item == null || item.payload['scope'] != _scope) {
        throw StateError('دسترسی مجاز نیست.');
      }
      final row = _outboxRow(item);
      return {
        ...row,
        'status': item.status.name,
        'attachments': [
          for (final file in row['attachments'] as List? ?? const [])
            if (file is Map)
              {
                'name': '',
                'filename': '${file['filename']}',
                'size': base64Decode('${file['content_base64'] ?? ''}').length,
                'is_image': RegExp(r'\.(png|jpe?g)$', caseSensitive: false)
                    .hasMatch('${file['filename']}'),
                'scope': 'general',
                'local': true,
              }
        ],
        'can_edit': false,
        'can_cancel': false,
      };
    }
    if (isLocal) throw StateError('درخواست نمایشی یافت نشد.');
    return Map<String, dynamic>.from(
        await read('get_request', {'name': name}) as Map);
  }

  // Comments -----------------------------------------------------------------

  Future<List<LocalRecord>> _savedComments(String entity, String name) async =>
      (await store.list(entityType: entity))
          .where((row) =>
              row.payload['scope'] == _scope && row.payload['name'] == name)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  RequestComment _savedComment(LocalRecord row, {required bool pending}) =>
      RequestComment(
        name: row.id,
        content: '${row.payload['content']}',
        author: _owner ?? '',
        authorName: isLocal ? 'کاربر پیش‌نمایش' : '',
        creation: row.createdAt.toIso8601String(),
        isMine: true,
        pending: pending,
      );

  /// The free comments of request [name], oldest first, followed by comments
  /// queued on this device («در انتظار ارسال»).
  Future<List<RequestComment>> comments(String name) async {
    await identify();
    if (isLocal) {
      return [
        for (final row in RequestDemoRegistry.comments(name))
          RequestComment.fromMap(row),
        for (final row in await _savedComments(_commentEntity, name))
          _savedComment(row, pending: false),
      ];
    }
    final server = [
      for (final row
          in await read('list_request_comments', {'name': name}) as List? ??
              const [])
        if (row is Map) RequestComment.fromMap(row)
    ];
    final queued = <RequestComment>[];
    for (final row in await _savedComments(_pendingCommentEntity, name)) {
      final content = '${row.payload['content']}';
      if (server.any((c) => c.isMine && c.content.trim() == content)) {
        // The queue delivered it.
        await store.delete(row.id);
      } else {
        queued.add(_savedComment(row, pending: true));
      }
    }
    return [...server, ...queued];
  }

  /// Adds a free comment. While offline the call is queued by the mutation
  /// queue and a local comment with `pending: true` is returned.
  Future<RequestComment> addComment(String name, String text) async {
    final content = text.trim();
    if (content.isEmpty) {
      throw const ApiException(
          kind: ApiFailureKind.validation, message: 'متن نظر را وارد کنید.');
    }
    await identify();
    String newId() => key('comment:$name:${requestId()}');
    if (isLocal) {
      final row = await store.save(
          id: newId(),
          entityType: _commentEntity,
          payload: {'scope': _scope, 'name': name, 'content': content});
      return _savedComment(row, pending: false);
    }
    try {
      final result = await remote(
          'add_request_comment', {'name': name, 'content': content});
      return RequestComment.fromMap(result as Map);
    } catch (error) {
      if (!offline(error)) rethrow;
      final row = await store.save(
          id: newId(),
          entityType: _pendingCommentEntity,
          status: LocalSyncStatus.pendingSync,
          payload: {'scope': _scope, 'name': name, 'content': content});
      return _savedComment(row, pending: true);
    }
  }

  // Leave --------------------------------------------------------------------

  /// The signed-in employee's leave balance (§4.11); the last answer is used
  /// while offline.
  Future<LeaveBalance> leaveBalance() async {
    await identify();
    if (isLocal) return LeaveBalance.fromMap(offlineLeaveBalance());
    return LeaveBalance.fromMap(await read(
            'get_leave_balance', {'company': company}, module: 'leave_request')
        as Map);
  }

  /// Dry-runs the leave rules (§4.11). [args]: `leave_type`, `request_kind`,
  /// `start_date`, `end_date`, `leave_date`, `start_time`, `end_time`.
  /// Business errors are in the result, never thrown.
  Future<LeavePreview> previewLeave(Map<String, dynamic> args) async {
    await identify();
    if (isLocal) return LeavePreview.fromMap(offlinePreviewLeave(args));
    return LeavePreview.fromMap(await read(
        'preview_leave_request',
        {
          'company': company,
          for (final entry in args.entries)
            if (entry.value != null && entry.value != '')
              entry.key: entry.value,
        },
        module: 'leave_request') as Map);
  }

  // Attachments --------------------------------------------------------------

  /// The content of the File [name] (`attachments[].name`). With [thumbnail]
  /// an image comes downscaled (at most 256 px) and is cached for offline use.
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
      String name,
      {bool thumbnail = false}) async {
    await identify();
    if (isLocal) {
      return (
        filename: 'نمونه.txt',
        contentType: 'text/plain',
        bytes: Uint8List.fromList(utf8.encode('فایل نمایشی'))
      );
    }
    final result = thumbnail
        ? await read('get_attachment', {'name': name, 'thumbnail': 1})
        : await remote('get_attachment', {'name': name});
    if (result is! Map || result['content_base64'] is! String) {
      throw const ApiException.protocol();
    }
    return (
      filename: '${result['filename'] ?? name}',
      contentType: '${result['content_type'] ?? ''}',
      bytes: base64Decode(result['content_base64'] as String),
    );
  }
}
