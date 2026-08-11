import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/purchase_request.dart';
import '../domain/purchase_request_repository.dart';

class FrappePurchaseRequestRepository implements PurchaseRequestRepository {
  const FrappePurchaseRequestRepository(this._client);
  static const _offlineKey = 'asoud_offline_purchase_requests_v1';
  final FrappeClient _client;

  bool _networkFailure(Object error) =>
      error is ApiException &&
      {ApiFailureKind.network, ApiFailureKind.timeout, ApiFailureKind.server}
          .contains(error.kind);

  @override
  Future<List<PurchaseRequestSummary>> list(String company) async {
    try {
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
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      final preferences = await SharedPreferences.getInstance();
      final current = preferences.getStringList(_offlineKey) ?? const [];
      return current.map((raw) {
        final item = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final name = item['name']?.toString() ?? '';
        return PurchaseRequestSummary(
          name: name,
          status: 'در انتظار همگام‌سازی',
          workflowInstance:
              name.length > 9 ? 'LOCAL-WFI-${name.substring(9)}' : '',
          scheduleDate:
              DateTime.tryParse(item['schedule_date']?.toString() ?? ''),
          localOnly: true,
        );
      }).toList(growable: false);
    }
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
