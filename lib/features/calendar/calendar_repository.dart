import 'dart:convert';
import 'dart:math';

import '../../core/config/app_config.dart';
import 'calendar_device_notifications.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/frappe_client.dart';
import '../../core/offline/session_preferences.dart';

typedef CalendarRow = Map<String, dynamic>;
CalendarRow calendarMap(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? {});
List<CalendarRow> calendarRows(Object? value) =>
    (value as List? ?? []).map(calendarMap).toList();
String calendarDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String calendarId() => List.generate(
      24,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();

/// Private cache and outbox: never replay across users, sites or companies.
class CalendarRepository {
  CalendarRepository(this.client, this.company);
  final FrappeApiClient? client;
  final String company;
  String? _identity;
  static Future<void>? _writes;
  SessionPreferences get _preferences => SessionPreferences(client);

  Future<String> _scope() async {
    final api = client;
    final user = api != null && api.isAuthenticated
        ? (api is FrappeClient ? api.localStorageUserId : null) ??
            (await api.getCurrentUser()).userId
        : '__local__';
    final site =
        api is FrappeClient ? api.serverIdentity : AppConfig.erpNextBaseUrl;
    final key =
        'asoud_calendar_v1:${Uri.encodeComponent(site)}:${Uri.encodeComponent(user)}:${Uri.encodeComponent(company)}';
    if (_identity != null && key != _identity) {
      throw StateError('حساب تغییر کرده است؛ تقویم را دوباره باز کنید.');
    }
    _identity = key;
    return key;
  }

  bool get onlineSession => client?.isAuthenticated == true;
  bool _offline(Object e) =>
      e is ApiException &&
      (e.kind == ApiFailureKind.network ||
          e.kind == ApiFailureKind.timeout ||
          (e.kind == ApiFailureKind.server &&
              [502, 503, 504].contains(e.statusCode)));

  Future<CalendarRow> _call(String method, CalendarRow data) async {
    await _scope();
    late final Map<String, dynamic> response;
    try {
      response = await client!.callMethod(
        'asoud_erp.api.v1.calendar.$method',
        data: {'company': company, ...data},
      );
    } on ApiException catch (e) {
      // Frappe can report missing Python modules as HTTP 417 (validation).
      // Match this endpoint specifically; never downgrade permission failures.
      if (e.kind != ApiFailureKind.forbidden &&
          e.kind != ApiFailureKind.unauthenticated &&
          e.message.contains('asoud_erp.api.v1.calendar') &&
          (e.message.contains('No module named') ||
              e.message.contains('has no attribute'))) {
        throw const ApiException(
          kind: ApiFailureKind.server,
          code: 'CALENDAR_NOT_DEPLOYED',
          message:
              'سرویس تقویم روی سرور به‌روز نشده است. یادآورهای شخصی روی دستگاه ذخیره می‌شوند؛ ارسال آن‌ها و ثبت تعطیلی سازمانی پس از به‌روزرسانی سرور ممکن است.',
        );
      }
      rethrow;
    }
    final envelope = calendarMap(response['message']);
    if (envelope['ok'] != true) throw const ApiException.protocol();
    return calendarMap(envelope['data']);
  }

  Future<CalendarRow> actionCounts(DateTime now) async {
    if (!onlineSession) throw StateError('برای دریافت آمار واقعی به سرور متصل شوید.');
    final result = await _call('get_calendar', {
      'start': calendarDate(now), 'end': calendarDate(now), 'summary_only': 1,
    });
    return calendarMap(result['action_counts']);
  }

  Future<String> notificationScope() => _scope();

  Future<CalendarRow> _read() async {
    final key = await _scope();
    return calendarMap(
      jsonDecode(
        await _preferences.read(key) ?? '{}',
      ),
    );
  }

  Future<void> _write(CalendarRow state) async {
    final key = await _scope();
    if (!await _preferences.write(
      key,
      jsonEncode(state),
    )) {
      throw StateError('ذخیره تقویم روی دستگاه انجام نشد.');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    // Keep only in-flight work. A completed Future retains its originating
    // zone; reusing it can strand later callers in a disposed async context.
    final previous = _writes;
    final result = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    final settled = result.then<void>((_) {}, onError: (Object _) {});
    _writes = settled;
    settled.then((_) {
      if (identical(_writes, settled)) _writes = null;
    });
    return result;
  }

  Future<CalendarRow> load(DateTime from, DateTime to,
          {bool refreshRemote = true}) =>
      _serial(() async {
        var state = await _read();
        if (!_preferences.isolated) {
          await CalendarDeviceNotifications.instance.activate(await _scope());
        }
        final range = '${calendarDate(from)}:${calendarDate(to)}';
        var cached = true;
        String? warning;
        if (onlineSession && refreshRemote) {
          try {
            final result = await _call('get_calendar', {
              'start': calendarDate(from),
              'end': calendarDate(to),
            });
            final cache = calendarMap(state['ranges']);
            // A fresh range supersedes overlapping stale cache rows, including deletions.
            for (final key in cache.keys.toList()) {
              final previous = calendarMap(cache[key]);
              previous['items'] = calendarRows(previous['items']).where((row) =>
                '${row['date']}'.compareTo(calendarDate(to)) > 0 ||
                '${row['end_date'] ?? row['date']}'.compareTo(calendarDate(from)) < 0).toList();
              cache[key] = previous;
            }
            cache.remove(range);
            cache[range] = result;
            while (cache.length > 24) {
              cache.remove(cache.keys.first);
            }
            state = {...state, 'ranges': cache};
            await _write(state);
            cached = false;
          } catch (e) {
            if (!_offline(e) &&
                !(e is ApiException &&
                    (e.kind == ApiFailureKind.server ||
                        e.kind == ApiFailureKind.protocol))) {
              rethrow;
            }
            warning = e is ApiException && e.code == 'CALENDAR_NOT_DEPLOYED'
                ? e.message
                : 'دریافت تقویم از سرور انجام نشد؛ اطلاعات دستگاه نمایش داده می‌شود.';
          }
        }
        final data = calendarMap(calendarMap(state['ranges'])[range]);
        final rows = calendarRows(data['items']);
        final pending = calendarRows(state['pending']);
        for (final edit in pending) {
          rows.removeWhere((r) => r['id'] == edit['id']);
          if (edit['deleted'] != true &&
              '${edit['date']}'.compareTo(calendarDate(to)) <= 0 &&
              '${edit['end_date'] ?? edit['date']}'
                      .compareTo(calendarDate(from)) >=
                  0) {
            rows.add({...edit, 'pending': true});
          }
        }
        final preferences = calendarMap(state['device_preferences']);
        for (final row in rows) {
          row.addAll(calendarMap(preferences['${row['id']}']));
        }
        final reminders = <String, CalendarRow>{};
        for (final rangeData in calendarMap(state['ranges']).values) {
          for (final row in calendarRows(calendarMap(rangeData)['items'])) {
            if (row['kind'] == 'Reminder') {
              reminders['${row['id']}'] = {...row,
                ...calendarMap(preferences['${row['id']}'])};
            }
          }
        }
        for (final row in pending) {
          reminders['${row['id']}'] = {...row, ...calendarMap(preferences['${row['id']}'])};
        }
        String? notificationWarning;
        try {
          if (!_preferences.isolated) {
            await CalendarDeviceNotifications.instance.reconcile(await _scope(),
              reminders.values.toList(), timezone: data['timezone'] as String?);
          }
        } catch (_) {
          notificationWarning = 'زمان‌بندی اعلان گوشی تأیید نشد؛ مجوز اعلان و تنظیمات گوشی را بررسی کنید.';
        }
        return {
          ...data,
          'items': rows,
          'cached': cached,
          'can_manage': !cached && data['can_manage'] == true,
          'pending_count': pending.length,
          'load_warning': warning,
          'notification_warning': notificationWarning,
        };
      });

  Future<void> save(CalendarRow item) => _serial(() async {
        final state = await _read();
        if (_preferences.isolated) {
          await _call('save_personal', {'payload': jsonEncode({
            ...item, 'mutation_id': calendarId(),
          })});
          await _write({...state, 'ranges': <String, dynamic>{}});
          return;
        }
        final pending = calendarRows(state['pending']);
        final previous =
            pending.where((r) => r['id'] == item['id']).firstOrNull;
        pending.removeWhere((r) => r['id'] == item['id']);
        pending.add({
          ...item,
          'version': previous?['version'] ?? item['version'] ?? '',
          'mutation_id': calendarId(),
        });
        final preferences = calendarMap(state['device_preferences']);
        preferences['${item['id']}'] = {
          'notification_enabled': item['notification_enabled'] == true,
          'reminder_minutes': item['reminder_minutes'] ?? 0,
        };
        await _write({...state, 'pending': pending, 'device_preferences': preferences});
      });

  /// Explicit retry; business/permission/conflict failures stay visible, not hidden.
  Future<void> sync() => _serial(() async {
        if (!onlineSession) return;
        var state = await _read();
        final pending = calendarRows(state['pending']);
        while (pending.isNotEmpty) {
          try {
            await _call(
                'save_personal', {'payload': jsonEncode(pending.first)});
          } catch (e) {
            if (_offline(e)) return;
            rethrow;
          }
          pending.removeAt(0);
          state = {...state, 'pending': pending, 'ranges': <String, dynamic>{}};
          await _write(state);
        }
      });

  Future<void> holiday(CalendarRow item) async {
    if (!onlineSession) {
      throw StateError('مدیریت تعطیلی سازمانی نیاز به اتصال و مجوز سرور دارد.');
    }
    await _call('save_holiday', {'payload': jsonEncode(item)});
  }

  Future<void> readAlert(String id) async {
    if (!onlineSession) throw StateError('برای تأیید اعلان به سرور متصل شوید.');
    await _call('read_alert', {'name': id});
  }
}
