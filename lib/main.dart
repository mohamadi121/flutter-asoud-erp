import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/calendar/calendar_device_notifications.dart';
import 'features/request_templates/request_templates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await CalendarDeviceNotifications.instance.initialize();
  } catch (_) {
    // Delivery failure must not prevent sign-in; the calendar reports/retries it.
  }
  registerRequestTemplates();
  runApp(const AsoudErpApp());
}
