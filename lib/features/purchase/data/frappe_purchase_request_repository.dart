import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/offline_mutation_store.dart';
import '../domain/purchase_request.dart';
import '../domain/purchase_request_repository.dart';

class FrappePurchaseRequestRepository implements PurchaseRequestRepository {
  const FrappePurchaseRequestRepository(this._client, {this.pendingCreates});
  static const _offlineKey = 'asoud_offline_purchase_requests_v1';
  final FrappeClient _client;

  /// Still-unsent create payloads from the shared mutation queue. Injected in
  /// tests; by default it reads the staged `create_purchase_request`
  /// mutations so a replayed write stops showing its local mirror row.
  final Future<List<Map<String, dynamic>>> Function()? pendingCreates;

  bool _networkFailure(Object error) =>
      (error is ApiException &&
          {
            ApiFailureKind.network,
            ApiFailureKind.timeout,
            ApiFailureKind.server
          }.contains(error.kind)) ||
      error.runtimeType.toString() == 'QueuedOfflineException';

  Future<List<Map<String, dynamic>>?> _pendingCreatePayloads() async {
    try {
      if (pendingCreates != null) return await pendingCreates!();
      final queued = await OfflineMutationStore.instance.pending();
      return [
        for (final entry in queued)
          if ('${entry['target']}'.endsWith('.create_purchase_request') &&
              entry['payload'] is Map)
            Map<String, dynamic>.from(entry['payload'] as Map),
      ];
    } catch (_) {
      // The queue is unreadable: keep every local row rather than dropping
      // a write the server may not have received yet.
      return null;
    }
  }

  static String _fingerprint(Map<String, dynamic> item) => jsonEncode({
        'company': item['company'],
        'subject': item['subject'],
        'schedule_date': item['schedule_date'],
        'items': item['items'],
      });

  @override
  Future<List<PurchaseRequestSummary>> list(String company) async {
    var online = true;
    var server = const <PurchaseRequestSummary>[];
    try {
      server = await _fetchServer(company);
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      online = false;
    }
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_offlineKey) ?? const [];
    if (current.isEmpty) return server;
    final pending = await _pendingCreatePayloads();
    final pendingPrints =
        pending?.map(_fingerprint).toSet() ?? const <String>{};
    final keep = <String>[];
    final queued = <PurchaseRequestSummary>[];
    for (final raw in current) {
      final item = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // A local row whose mutation is no longer queued was replayed: drop
      // the mirror so the server row shows exactly once. While the queue
      // cannot be read, every row is kept.
      if (online &&
          pending != null &&
          !pendingPrints.contains(_fingerprint(item))) {
        continue;
      }
      keep.add(raw);
      queued.add(_pendingSummary(item));
    }
    if (keep.length != current.length) {
      await preferences.setStringList(_offlineKey, keep);
    }
    if (!online) return queued;
    return [...queued, ...server];
  }

  Future<List<PurchaseRequestSummary>> _fetchServer(String company) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.purchase_request.list_my_purchase_requests',
      data: {'company': company},
    );
    if (data is! List) throw const ApiException.protocol();
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return PurchaseRequestSummary(
        name: item['name']?.toString() ?? '',
        status: item['status']?.toString() ?? '',
        workflowInstance: item['workflow_instance']?.toString() ?? '',
        scheduleDate:
            DateTime.tryParse(item['schedule_date']?.toString() ?? ''),
      );
    }).toList(growable: false);
  }

  PurchaseRequestSummary _pendingSummary(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    return PurchaseRequestSummary(
      name: name,
      status: 'در انتظار ارسال',
      workflowInstance: name.length > 9 ? 'LOCAL-WFI-${name.substring(9)}' : '',
      scheduleDate: DateTime.tryParse(item['schedule_date']?.toString() ?? ''),
      localOnly: true,
    );
  }

  @override
  Future<PurchaseRequestOptions> options(String company) async {
    try {
      final data = await _client.callAsoudMethod(
        'asoud_erp.api.v1.purchase_request.purchase_request_options',
        data: {'company': company},
      );
      if (data is! Map) throw const ApiException.protocol();
      final map = Map<String, dynamic>.from(data);
      final rawItems = map['items'];
      final rawWarehouses = map['warehouses'];
      return PurchaseRequestOptions(
        items: rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  return PurchaseItemOption(
                    code: item['name']?.toString() ?? '',
                    name: item['item_name']?.toString() ?? '',
                    uom: item['stock_uom']?.toString() ?? '',
                  );
                })
                .where((item) => item.code.isNotEmpty)
                .toList(growable: false)
            : const [],
        warehouses: rawWarehouses is List
            ? rawWarehouses
                .whereType<Map>()
                .map((raw) => raw['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList(growable: false)
            : const [],
      );
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      return const PurchaseRequestOptions();
    }
  }

  @override
  Future<PurchaseRequestResult> create({
    required String company,
    required String subject,
    required DateTime scheduleDate,
    required List<PurchaseRequestLine> items,
  }) async {
    final payload = {
      'company': company,
      'subject': subject.trim(),
      'schedule_date': _date(scheduleDate),
      'items': items.map((item) => item.toMap()).toList(growable: false),
    };
    try {
      final data = await _client.callAsoudMethod(
        'asoud_erp.api.v1.purchase_request.create_purchase_request',
        data: payload,
      );
      if (data is! Map) throw const ApiException.protocol();
      final map = Map<String, dynamic>.from(data);
      return PurchaseRequestResult(
        name: map['name']?.toString() ?? '',
        workflowInstance: map['workflow_instance']?.toString() ?? '',
        localOnly: false,
      );
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      final preferences = await SharedPreferences.getInstance();
      final current = preferences.getStringList(_offlineKey) ?? const [];
      final id = 'LOCAL-PR-${DateTime.now().millisecondsSinceEpoch}';
      await preferences.setStringList(
        _offlineKey,
        [
          ...current,
          jsonEncode({'name': id, ...payload, 'pending_sync': true})
        ],
      );
      return PurchaseRequestResult(
        name: id,
        workflowInstance: 'LOCAL-WFI-${id.substring(9)}',
        localOnly: true,
      );
    }
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
