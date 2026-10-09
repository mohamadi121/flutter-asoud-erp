import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/offline_failure.dart';
import 'demo/employee_demo_data.dart';

/// Whether the check-in reached the server or is waiting in the offline queue.
enum CheckinResult { accepted, queued }

/// Attendance self-service (`asoud_erp.api.v1.hr_self_service`) for the
/// session user. Check-ins go through the client's offline mutation queue.
///
/// In the offline preview (no session) the demo history of «شرکت نمونه
/// آسود» is served and check-ins are kept on this device only.
class SelfServiceRepository {
  SelfServiceRepository(this.client);
  final FrappeApiClient client;

  static const _module = 'asoud_erp.api.v1.hr_self_service';
  static const _previewLogKey = 'asoud_preview_checkins_v1';

  bool get isLocal => AppConfig.offlineDemoMode && !client.isAuthenticated;

  bool _queued(Object error) =>
      error is TimeoutException ||
      isRetryableOfflineFailure(error) ||
      isQueuedOffline(error);

  Future<CheckinResult> checkin(String logType) async {
    if (isLocal) {
      // Offline preview: kept on this device only, never queued for a server.
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_previewLogKey) ?? const [];
      await preferences.setStringList(_previewLogKey, [
        '${DateTime.now().toIso8601String()}|$logType',
        ...raw,
      ]);
      return CheckinResult.accepted;
    }
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
      {String? fromDate, String? toDate}) async {
    if (isLocal) {
      final preferences = await SharedPreferences.getInstance();
      final own = preferences.getStringList(_previewLogKey) ?? const [];
      return [
        for (final entry in own)
          {
            'time': entry.split('|').first,
            'log_type': entry.split('|').last,
            'is_sample': true,
          },
        ...demoCheckins(),
      ];
    }
    return _rows(
        await client.callAsoudMethod('$_module.list_my_checkins', data: {
      if (fromDate != null) 'from_date': fromDate,
      if (toDate != null) 'to_date': toDate,
    }));
  }

  Future<List<Map<String, dynamic>>> attendance(
      String fromDate, String toDate) async {
    if (isLocal) return demoAttendance(fromDate, toDate);
    return _rows(await client.callAsoudMethod('$_module.list_my_attendance',
        data: {'from_date': fromDate, 'to_date': toDate}));
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}
