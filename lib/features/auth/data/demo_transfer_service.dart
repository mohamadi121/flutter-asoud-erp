import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/offline_failure.dart';
import '../../../core/offline/local_record.dart';
import '../../workflows/data/offline_preview_data.dart';

/// A preview row the user created in the offline demo that may be moved to
/// the server after signing in. Built-in sample/seed rows (`is_sample`) are
/// never listed here.
enum DemoTransferKind { genericRequest, workflowDesign, documentTemplate }

class DemoTransferItem {
  const DemoTransferItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.transferable,
    this.nonTransferReason,
    required this.payload,
  });

  final DemoTransferKind kind;
  final String id;
  final String title;
  final String subtitle;
  final bool transferable;
  final String? nonTransferReason;
  final Map<String, dynamic> payload;

  String get kindLabel => switch (kind) {
        DemoTransferKind.genericRequest => 'درخواست',
        DemoTransferKind.workflowDesign => 'طراحی گردش‌کار',
        DemoTransferKind.documentTemplate => 'الگوی سند',
      };
}

class DemoTransferService {
  DemoTransferService({LocalRecordStore? store})
      : _store = store ?? LocalDatabaseStore.instance;

  final LocalRecordStore _store;

  static const templatesKey = 'asoud_document_templates_local_v1';
  static const transferSeenKey = 'asoud_demo_transfer_seen_v1';

  /// Built-in workflow samples live in code and are never persisted as user
  /// rows; still, never offer them if a row with the same id is found.
  static const sampleDesignIds = {
    'PREVIEW-WF-001',
    'PREVIEW-WF-002',
    'PREVIEW-WF-003',
  };

  static Future<bool> isTransferSeen() async =>
      (await SharedPreferences.getInstance()).getBool(transferSeenKey) ?? false;

  static Future<void> markTransferSeen() async =>
      (await SharedPreferences.getInstance()).setBool(transferSeenKey, true);

  Future<List<DemoTransferItem>> listCandidates() async {
    final items = <DemoTransferItem>[];
    items.addAll(await _genericRequests());
    items.addAll(await _workflowDesigns());
    items.addAll(await _templates());
    return items;
  }

  Future<List<DemoTransferItem>> _genericRequests() async {
    final rows = await _store.list(entityType: 'generic_request_outbox');
    final items = <DemoTransferItem>[];
    for (final row in rows) {
      if (row.status != LocalSyncStatus.localOnly) continue;
      final payload = Map<String, dynamic>.from(row.payload);
      final data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'] as Map)
          : const <String, dynamic>{};
      if (data['is_sample'] == true) continue;
      items.add(DemoTransferItem(
        kind: DemoTransferKind.genericRequest,
        id: row.id,
        title: '${data['subject'] ?? 'درخواست بدون عنوان'}',
        subtitle: '${data['company'] ?? ''}',
        transferable: true,
        payload: payload,
      ));
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _readPrefsList(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DemoTransferItem>> _workflowDesigns() async {
    final designs = await _readPrefsList(previewDesignsKey);
    final items = <DemoTransferItem>[];
    for (final design in designs) {
      final workflow = design['workflow'] is Map
          ? Map<String, dynamic>.from(design['workflow'] as Map)
          : const <String, dynamic>{};
      final id = '${workflow['id'] ?? ''}';
      if (id.isEmpty ||
          workflow['is_sample'] == true ||
          sampleDesignIds.contains(id)) {
        continue;
      }
      items.add(DemoTransferItem(
        kind: DemoTransferKind.workflowDesign,
        id: id,
        title: '${workflow['title'] ?? 'طراحی بدون عنوان'}',
        subtitle: 'طراحی گردش‌کار',
        transferable: false,
        nonTransferReason:
            'شناسه مرحله‌های این طراحی محلی است و روی سرور معتبر نیست؛ لطفاً آن را روی حساب سازمانی از نو بسازید.',
        payload: design,
      ));
    }
    return items;
  }

  Future<List<DemoTransferItem>> _templates() async {
    final rows = await _readPrefsList(templatesKey);
    final items = <DemoTransferItem>[];
    for (final row in rows) {
      if (row['is_sample'] == true) continue;
      final name = '${row['name'] ?? ''}';
      if (name.isEmpty) continue;
      items.add(DemoTransferItem(
        kind: DemoTransferKind.documentTemplate,
        id: name,
        title: '${row['title'] ?? 'الگوی بدون عنوان'}',
        subtitle: '${row['module'] ?? ''} ${row['document_type'] ?? ''}'.trim(),
        transferable: true,
        payload: row,
      ));
    }
    return items;
  }

  /// The `request_id` a preview request is sent with: derived from the preview
  /// row, so every attempt for the same row carries the same key and the
  /// server replays the first result instead of creating a second request. It
  /// is 46 characters; the server accepts 8 to 100.
  static String requestIdFor(DemoTransferItem item) {
    var high = 0xcbf29ce484222325, low = 0x84222325cbf29ce4;
    for (final unit in utf8.encode(item.id)) {
      high = ((high ^ unit) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      low = ((low ^ unit) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      low = ((low << 7) | (low >>> 57)) & 0xFFFFFFFFFFFFFFFF;
    }
    String hex(int value) =>
        value.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    return 'demo-transfer-${hex(high)}${hex(low)}';
  }

  /// Submits a preview request as a normal server write (queued when
  /// offline by the repository) and removes the local preview copy. The
  /// request is sent with [requestIdFor] as its `request_id`. Returns true
  /// when the write was only queued on this device: it is then safe, so the
  /// preview copy is removed as well and a second send would be a duplicate.
  Future<bool> transferGenericRequest(
    DemoTransferItem item, {
    required Future<dynamic> Function(Map<String, dynamic> data) submit,
  }) async {
    assert(item.kind == DemoTransferKind.genericRequest);
    final data =
        Map<String, dynamic>.from((item.payload['data'] as Map?) ?? const {})
          ..['request_id'] = requestIdFor(item);
    final queued = await _submitOrQueued(() => submit(data));
    await _store.delete(item.id);
    return queued;
  }

  /// Submits a preview document template as a normal server write and
  /// removes the local preview copy. Returns true when the write was only
  /// queued on this device (see [transferGenericRequest]).
  Future<bool> transferTemplate(
    DemoTransferItem item, {
    required Future<dynamic> Function(Map<String, dynamic> template) submit,
  }) async {
    assert(item.kind == DemoTransferKind.documentTemplate);
    final queued = await _submitOrQueued(
        () => submit(Map<String, dynamic>.from(item.payload)));
    await _removePrefsRow(templatesKey, item.id);
    return queued;
  }

  /// A write that was safely queued did not fail: the queue sends it later.
  Future<bool> _submitOrQueued(Future<dynamic> Function() submit) async {
    try {
      await submit();
      return false;
    } catch (error) {
      if (isQueuedOffline(error)) return true;
      rethrow;
    }
  }

  /// Discards a preview copy without sending it to the server.
  Future<void> ignore(DemoTransferItem item) async {
    switch (item.kind) {
      case DemoTransferKind.genericRequest:
        await _store.delete(item.id);
      case DemoTransferKind.workflowDesign:
        await _removeDesign(item.id);
      case DemoTransferKind.documentTemplate:
        await _removePrefsRow(templatesKey, item.id);
    }
  }

  Future<void> _removeDesign(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final designs = await _readPrefsList(previewDesignsKey);
    designs.removeWhere((design) {
      final workflow = design['workflow'];
      return workflow is Map && '${workflow['id']}' == id;
    });
    await preferences.setString(previewDesignsKey, jsonEncode(designs));
  }

  Future<void> _removePrefsRow(String key, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final rows = await _readPrefsList(key);
    rows.removeWhere((row) => '${row['name']}' == id || '${row['id']}' == id);
    await preferences.setString(key, jsonEncode(rows));
  }
}
