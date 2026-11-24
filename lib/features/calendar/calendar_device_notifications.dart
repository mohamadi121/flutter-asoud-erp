import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// Device delivery only. Native Event remains the reminder's source of truth.
class CalendarDeviceNotifications {
  CalendarDeviceNotifications._();
  static final instance = CalendarDeviceNotifications._();
  final plugin = FlutterLocalNotificationsPlugin();
  final opened = ValueNotifier<Map<String, dynamic>?>(null);
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  static const _registry = 'asoud_calendar_notification_registry_v1';
  bool get supported =>
      !kIsWeb &&
      [TargetPlatform.android, TargetPlatform.iOS]
          .contains(defaultTargetPlatform);

  Future<void> initialize() async {
    try {
      await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (!supported) return;
    zones.initializeTimeZones();
    void accept(String? payload) {
      try {
        final row = jsonDecode(payload ?? '') as Map<String, dynamic>;
        if (row['calendar'] == true) opened.value = row;
      } catch (_) {
        // Not one of this calendar's notifications.
      }
    }

    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_calendar_notification'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)),
        onDidReceiveNotificationResponse: (response) =>
            accept(response.payload));
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      accept(launch?.notificationResponse?.payload);
    }
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Only one signed-in office may own visible notifications on this device.
  Future<void> activate(String scope) => _serial(() async {
        if (!supported) return;
        await initialize();
        final prefs = await SharedPreferences.getInstance();
        final state = Map<String, dynamic>.from(
            jsonDecode(prefs.getString(_registry) ?? '{}') as Map);
        if (state['scope'] == scope) return;
        for (final value in (state['ids'] as Map? ?? {}).values) {
          await plugin.cancel((value as num).toInt());
        }
        await prefs.setString(
            _registry, jsonEncode({'scope': scope, 'ids': {}}));
      });

  Future<void> clear() async {
    opened.value = null;
    await activate('');
  }

  Future<void> reconcile(String scope, List<Map<String, dynamic>> rows,
          {String? timezone}) =>
      _serial(() async {
        if (!supported) return;
        await initialize();
        final prefs = await SharedPreferences.getInstance();
        final state = Map<String, dynamic>.from(
            jsonDecode(prefs.getString(_registry) ?? '{}') as Map);
        if (state['scope'] != scope) {
          return; // An old load must not reschedule another office.
        }
        final ids = Map<String, dynamic>.from(state['ids'] as Map? ?? {});
        final known = rows
            .where((r) => r['kind'] == 'Reminder')
            .map((r) => '${r['id']}')
            .toSet();
        for (final key
            in ids.keys.where((key) => !known.contains(key)).toList()) {
          await plugin.cancel((ids.remove(key) as num).toInt());
        }
        for (final row in rows) {
          if (row['kind'] != 'Reminder') {
            continue;
          }
          final key = '${row['id']}';
          var id = (ids[key] as num?)?.toInt();
          final eligible = row['notification_enabled'] == true &&
              row['done'] != true &&
              row['deleted'] != true;
          if (!eligible) {
            if (id != null) {
              await plugin.cancel(id);
            }
            ids.remove(key);
            continue;
          }
          final parts = '${row['time'] ?? '09:00'}'.split(':');
          final date = DateTime.tryParse('${row['date']}');
          if (date == null || parts.length != 2) continue;
          tz.TZDateTime due;
          if (timezone != null && timezone.isNotEmpty) {
            // Never silently substitute Tehran or UTC for an unknown office zone.
            final zone = tz.getLocation(timezone);
            due = tz.TZDateTime(zone, date.year, date.month, date.day,
                int.parse(parts[0]), int.parse(parts[1]));
          } else {
            due = tz.TZDateTime.from(
                DateTime(date.year, date.month, date.day, int.parse(parts[0]),
                    int.parse(parts[1])),
                tz.UTC);
          }
          final fire = due.subtract(Duration(
              minutes: (row['reminder_minutes'] as num? ?? 0).toInt()));
          if (!fire.isAfter(tz.TZDateTime.now(tz.UTC))) {
            if (id != null) await plugin.cancel(id);
            ids.remove(key);
            continue;
          }
          if (id == null) {
            if (defaultTargetPlatform == TargetPlatform.iOS &&
                ids.length >= 60) {
              throw StateError('سقف یادآورهای زمان‌بندی‌شده گوشی پر است.');
            }
            final used = ids.values.toSet();
            id = 1200000000;
            while (used.contains(id)) {
              id = id! + 1;
            }
            ids[key] = id;
            // Persist the delivery ID before scheduling so retries replace, never duplicate.
            await prefs.setString(
                _registry, jsonEncode({'scope': scope, 'ids': ids}));
          }
          await plugin.zonedSchedule(
              id!,
              '${row['title']}',
              'یادآور شخصی',
              fire,
              const NotificationDetails(
                  android: AndroidNotificationDetails(
                      'asoud_calendar', 'یادآورهای شخصی',
                      channelDescription: 'زمان‌بندی یادآورهای دفتر فعال',
                      importance: Importance.defaultImportance),
                  iOS: DarwinNotificationDetails()),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: jsonEncode({
                'calendar': true,
                'scope': scope,
                'id': key,
                'date': row['date']
              }));
        }
        await prefs.setString(
            _registry, jsonEncode({'scope': scope, 'ids': ids}));
      });
}
