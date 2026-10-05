import 'dart:async';

import '../../../core/network/frappe_client.dart';
import '../../../core/offline/offline_failure.dart';

/// Whether the check-in reached the server or is waiting in the offline queue.
enum CheckinResult { accepted, queued }

/// Attendance self-service (`asoud_erp.api.v1.hr_self_service`) for the
/// session user. Check-ins go through the client's offline mutation queue.
class SelfServiceRepository {
  SelfServiceRepository(this.client);
  final FrappeApiClient client;

  static const _module = 'asoud_erp.api.v1.hr_self_service';

  bool _queued(Object error) =>
      error is TimeoutException ||
      isRetryableOfflineFailure(error) ||
      isQueuedOffline(error);

  Future<CheckinResult> checkin(String logType) async {
    try {
      await client.callAsoudMethod('$_module.create_checkin',
          data: {'log_type': logType});
      return CheckinResult.accepted;
    } catch (error) {
      // The write is staged in the offline queue and replays automatically.
      if (_queued(error)) return CheckinResult.queued;
      rethrow;
    }
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
