import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/frappe_client.dart';

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

  Future<String> _scope() async {
    final api = client;
    final user = api != null && api.isAuthenticated
        ? (await api.getCurrentUser()).userId
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
    final response = await client!.callMethod(
      'asoud_erp.api.v1.calendar.$method',
      data: {'company': company, ...data},
    );
    final envelope = calendarMap(response['message']);
    if (envelope['ok'] != true) throw const ApiException.protocol();
    return calendarMap(envelope['data']);
  }

  Future<CalendarRow> _read() async {
    final key = await _scope();
    return calendarMap(
      jsonDecode(
        (await SharedPreferences.getInstance()).getString(key) ?? '{}',
      ),
    );
  }

  Future<void> _write(CalendarRow state) async {
    final key = await _scope();
    if (!await (await SharedPreferences.getInstance()).setString(
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

  Future<CalendarRow> load(DateTime from, DateTime to) => _serial(() async {
        var state = await _read();
        final range = '${calendarDate(from)}:${calendarDate(to)}';
        var cached = true;
        if (onlineSession) {
          try {
            final result = await _call('get_calendar', {
              'start': calendarDate(from),
              'end': calendarDate(to),
            });
            final cache = calendarMap(state['ranges']);
            cache[range] = result;
            while (cache.length > 24) {
              cache.remove(cache.keys.first);
            }
            state = {...state, 'ranges': cache};
            await _write(state);
            cached = false;
          } catch (e) {
            if (!_offline(e)) rethrow;
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
        return {
          ...data,
          'items': rows,
          'cached': cached,
          'can_manage': !cached && data['can_manage'] == true,
          'pending_count': pending.length,
        };
      });

  Future<void> save(CalendarRow item) => _serial(() async {
        final state = await _read();
        final pending = calendarRows(state['pending']);
        final previous =
            pending.where((r) => r['id'] == item['id']).firstOrNull;
        pending.removeWhere((r) => r['id'] == item['id']);
        pending.add({
          ...item,
          'version': previous?['version'] ?? item['version'] ?? '',
          'mutation_id': calendarId(),
        });
        await _write({...state, 'pending': pending});
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
