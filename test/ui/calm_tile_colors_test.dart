import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/theme/asoud_tile_colors.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/accounting_home_page.dart';
import 'package:asoud_erp/features/calendar/calendar_page.dart';
import 'package:asoud_erp/features/calendar/calendar_repository.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo extends CalendarRepository {
  _Repo(this.rows) : super(null, 'شرکت نمونه');
  final List<CalendarRow> rows;
  @override
  Future<CalendarRow> load(DateTime from, DateTime to,
          {bool refreshRemote = true}) async =>
      {'items': rows};
  @override
  Future<String> notificationScope() async => 'test';
}

CalendarRow _row(String date, String kind, {bool overdue = false}) => {
      'id': '$date-$kind',
      'date': date,
      'title': 'نمونه',
      'kind': kind,
      'overdue': overdue,
    };

Future<void> _pump(WidgetTester tester, Widget child, double width,
    {bool scroll = true}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
        textDirection: TextDirection.rtl,
        child: scroll
            ? Scaffold(body: SingleChildScrollView(child: child))
            : child),
  ));
  await tester.pumpAndSettle();
}

// Colour of the day tile for [date], found by its Semantics label.
Color _dayColor(WidgetTester tester, DateTime date) {
  final label = find.byWidgetPredicate((w) =>
      w is Semantics &&
      (w.properties.label ?? '').startsWith(formatJalaliLong(date)));
  expect(label, findsOneWidget);
  final material =
      find.descendant(of: label, matching: find.byType(Material)).first;
  return tester.widget<Material>(material).color!;
}

void main() {
  group('AsoudTileColors', () {
    test('status colours differ from the shared base surface', () {
      final base = AsoudTileColors.dayBackground(
          selected: false, overdue: false, holiday: false, today: false);
      final statuses = {
        'selected': AsoudTileColors.dayBackground(
            selected: true, overdue: false, holiday: false, today: false),
        'overdue': AsoudTileColors.dayBackground(
            selected: false, overdue: true, holiday: false, today: false),
        'holiday': AsoudTileColors.dayBackground(
            selected: false, overdue: false, holiday: true, today: false),
        'today': AsoudTileColors.dayBackground(
            selected: false, overdue: false, holiday: false, today: true),
      };
      expect(base, AsoudTileColors.daySurface);
      for (final entry in statuses.entries) {
        expect(entry.value, isNot(base), reason: entry.key);
      }
      expect(statuses.values.toSet().length, statuses.length);
    });

    test('disabled differs from base', () {
      expect(AsoudTileColors.disabled, isNot(AsoudTileColors.base));
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('calendar days: base shared, status coloured at ${width}px',
        (tester) async {
      final repo = _Repo([
        _row('2026-11-26', 'Event'),
        _row('2026-11-30', 'Task', overdue: true),
        _row('2026-12-01', 'Reminder'),
      ]);
      await _pump(
        tester,
        AsoudCalendar(
          company: 'شرکت نمونه',
          compact: true,
          repository: repo,
          now: DateTime(2026, 11, 28),
          initialDate: DateTime(2026, 11, 29),
        ),
        width,
      );
      expect(tester.takeException(), isNull);
      final base = AsoudTileColors.daySurface;
      // Event, reminder and plain days all use the same base colour.
      expect(_dayColor(tester, DateTime(2026, 11, 26)), base);
      expect(_dayColor(tester, DateTime(2026, 12, 1)), base);
      expect(_dayColor(tester, DateTime(2026, 12, 2)), base);
      // Status days differ from the base.
      expect(
          _dayColor(tester, DateTime(2026, 11, 30)), AsoudColors.dangerSurface);
      expect(_dayColor(tester, DateTime(2026, 11, 27)),
          AsoudColors.warningSurface); // Friday
      expect(
          _dayColor(tester, DateTime(2026, 11, 28)),
          AsoudTileColors.dayBackground(
              selected: false, overdue: false, holiday: false, today: true));
      expect(_dayColor(tester, DateTime(2026, 11, 28)), isNot(base));
      expect(_dayColor(tester, DateTime(2026, 11, 29)), AsoudColors.primary);
    });

    testWidgets('accounting hub tiles share one icon colour at ${width}px',
        (tester) async {
      await _pump(tester, const AccountingHomePage(), width, scroll: false);
      expect(tester.takeException(), isNull);
      final colors = tester
          .widgetList<AsoudIconBox>(find.byType(AsoudIconBox))
          .map((box) => box.color)
          .toSet();
      expect(colors, {AsoudTileColors.base, AsoudTileColors.disabled});
    });
  }
}
