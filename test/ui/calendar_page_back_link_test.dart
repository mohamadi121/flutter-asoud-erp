import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/calendar/calendar_page.dart';
import 'package:asoud_erp/features/calendar/calendar_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CalendarRepo extends Fake implements CalendarRepository {
  _CalendarRepo(this.client, this.company);

  @override
  final FrappeApiClient? client;

  @override
  final String company;

  @override
  Future<CalendarRow> load(DateTime from, DateTime to,
          {bool refreshRemote = true}) async =>
      {'items': <Map<String, dynamic>>[], 'alerts': <Map<String, dynamic>>[]};

  @override
  Future<String> notificationScope() async => 'scope';

  @override
  Future<void> save(CalendarRow item) async {}

  @override
  Future<void> sync() async {}

  @override
  Future<void> holiday(CalendarRow item) async {}

  @override
  Future<void> readAlert(String id) async {}
}

Widget _app(Widget page) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: page));

void main() {
  testWidgets('full calendar keeps one back control and one title',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AsoudCalendar(
        company: 'شرکت',
        repository: _CalendarRepo(null, 'شرکت'),
        now: DateTime(2026, 9, 25))));
    await tester.pumpAndSettle();

    // The header carries the single «تقویم من» title and the back chevron;
    // the duplicate «بازگشت به خانه» link and the second content title are gone.
    expect(find.text('تقویم من'), findsOneWidget);
    expect(find.text('بازگشت به خانه'), findsNothing);
    expect(find.text('برنامه هفتگی من'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact calendar keeps its own title and full-calendar button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AsoudCalendar(
        company: 'شرکت',
        repository: _CalendarRepo(null, 'شرکت'),
        compact: true,
        now: DateTime(2026, 9, 25))));
    await tester.pumpAndSettle();

    // Compact mode has no header, so it keeps its own title and the
    // «تقویم کامل» button; it never shows the full-page title or back link.
    expect(find.text('برنامه هفتگی من'), findsOneWidget);
    expect(find.text('تقویم کامل'), findsOneWidget);
    expect(find.text('تقویم من'), findsNothing);
    expect(find.text('بازگشت به خانه'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
