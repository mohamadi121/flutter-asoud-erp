import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/reports/presentation/pages/report_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('date filter uses the Jalali picker and submits Gregorian dates',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? company;
    DateTime? from, to;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ReportFilters(
          requireAccount: false,
          onSubmit: (c, f, t, a, p, s) {
            company = c;
            from = f;
            to = t;
          },
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField).first, 'شرکت نمونه');

    await tester.tap(find.textContaining('از تاریخ'));
    await tester.pumpAndSettle();
    // The picker is Jalali: it must show a Persian month name, not an
    // English/Gregorian one.
    final initial =
        JalaliDate.fromDateTime(DateTime(DateTime.now().year, 1, 1));
    expect(find.text(JalaliDate.monthNames[initial.month - 1]), findsWidgets);

    // Pick day 5 of the displayed Jalali month.
    await tester.tap(find.text('۵'));
    await tester.pumpAndSettle();
    expect(find.text(JalaliDate.monthNames[initial.month - 1]), findsNothing);

    await tester.tap(find.text('نمایش گزارش'));
    await tester.pumpAndSettle();

    final expected = parseJalaliDate('${initial.year}/${initial.month}/5')!;
    expect(company, 'شرکت نمونه');
    // The payload stays Gregorian ISO, not the Jalali display value.
    expect(from, expected);
    expect(from!.toIso8601String().split('T').first,
        expected.toIso8601String().split('T').first);
    expect(to, isNotNull);
    expect(tester.takeException(), isNull);
  });
}