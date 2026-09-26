import '../../../core/network/frappe_client.dart';

/// Attendance self-service (`asoud_erp.api.v1.hr_self_service`) for the
/// session user. Check-ins go through the client's offline mutation queue.
class SelfServiceRepository {
  SelfServiceRepository(this.client);
  final FrappeApiClient client;

  static const _module = 'asoud_erp.api.v1.hr_self_service';

  Future<void> checkin(String logType) async {
    await client.callAsoudMethod('$_module.create_checkin',
        data: {'log_type': logType});
  }

  Future<List<Map<String, dynamic>>> checkins(
          {String? fromDate, String? toDate}) async =>
      _rows(await client.callAsoudMethod('$_module.list_my_checkins', data: {
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
      }));

  Future<List<Map<String, dynamic>>> attendance(
          String fromDate, String toDate) async =>
      _rows(await client.callAsoudMethod('$_module.list_my_attendance',
          data: {'from_date': fromDate, 'to_date': toDate}));

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}
