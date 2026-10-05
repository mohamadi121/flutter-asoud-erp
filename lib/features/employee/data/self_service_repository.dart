import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/frappe_client.dart';
import 'demo/employee_demo_data.dart';

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

  Future<void> checkin(String logType) async {
    if (isLocal) {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_previewLogKey) ?? const [];
      await preferences.setStringList(_previewLogKey, [
        '${DateTime.now().toIso8601String()}|$logType',
        ...raw,
      ]);
      return;
    }
    await client.callAsoudMethod('$_module.create_checkin',
        data: {'log_type': logType});
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
