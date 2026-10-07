import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(page));
  await tester.pumpAndSettle();
}

Finder _tab(String key) => find.byKey(ValueKey('request-tab:$key'));

void main() {
  testWidgets('purchase list: title, tabs with counts, search and cards',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        PurchaseRequestsListPage(
            company: repository.company, repository: repository));
    expect(find.text('درخواست‌های خرید'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('جستجو در درخواست‌های خرید ...'), findsOneWidget);
    // Tabs and the server's counts: 4 purchase rows, 2 pending, 1 and 1.
    for (final entry in {
      'all': ('همه', '۴'),
      'pending': ('در انتظار بررسی', '۲'),
      'approved': ('تأیید شده', '۱'),
      'rejected': ('رد شده', '۱'),
    }.entries) {
      expect(
          find.descendant(
              of: _tab(entry.key), matching: find.text(entry.value.$1)),
          findsOneWidget);
      expect(
          find.descendant(
              of: _tab(entry.key), matching: find.text(entry.value.$2)),
          findsOneWidget,
          reason: entry.key);
    }
    // The card of the mockup row.
    expect(find.text('PR-1404-0023'), findsOneWidget);
    expect(find.text('خرید تجهیزات پزشکی بخش ICU'), findsOneWidget);
    expect(find.text('ارسال شده'), findsWidgets);
    expect(find.text('علی محمدی'), findsWidgets);
    expect(find.textContaining('بخش ICU · توسعه بخش ICU'), findsOneWidget);
    expect(find.text('۳ قلم'), findsOneWidget);
    expect(find.text('۲'), findsWidgets);
    // Jalali date (creation of the row is today: 2026-10-06 = 1405/07/14).
    expect(find.text('۱۴۰۵/۰۷/۱۴'), findsWidgets);
    // Leave and supply rows are not in this list.
    expect(find.text('LV-1404-0042'), findsNothing);
    expect(find.text('SP-1404-0007'), findsNothing);
  });

  testWidgets('tabs filter by status group', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        PurchaseRequestsListPage(
            company: repository.company, repository: repository));
    await tester.tap(_tab('rejected'));
    await tester.pumpAndSettle();
    expect(find.text('PR-1404-0020'), findsOneWidget);
    expect(find.text('PR-1404-0023'), findsNothing);
    await tester.tap(_tab('approved'));
    await tester.pumpAndSettle();
    expect(find.text('PR-1404-0022'), findsOneWidget);
    expect(find.text('PR-1404-0020'), findsNothing);
  });

  testWidgets('search narrows the list (debounced)', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        PurchaseRequestsListPage(
            company: repository.company, repository: repository));
    await tester.enterText(find.byType(TextField), 'شبکه');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('PR-1404-0021'), findsOneWidget);
    expect(find.text('PR-1404-0023'), findsNothing);
  });

  testWidgets('supply list uses its own title and shows the supply method',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        SupplyRequestsListPage(
            company: repository.company, repository: repository));
    expect(find.text('درخواست‌های تأمین کالا / خدمات'), findsOneWidget);
    expect(find.text('SP-1404-0007'), findsOneWidget);
    expect(find.text('SP-1404-0006'), findsOneWidget);
    expect(find.text('از انبار'), findsOneWidget);
    expect(find.text('خرید'), findsOneWidget);
    expect(find.text('PR-1404-0023'), findsNothing);
  });

  testWidgets('leave list: cards with dates, duration and location',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        LeaveRequestsListPage(
            company: repository.company, repository: repository));
    expect(find.text('درخواست‌های مرخصی'), findsOneWidget);
    expect(find.text('جستجو در درخواست‌های مرخصی ...'), findsOneWidget);
    expect(_tab('all'), findsOneWidget);
    // LV-1404-0042: annual, daily, 3 days (2026-10-10 .. 2026-10-12).
    expect(find.text('LV-1404-0042'), findsOneWidget);
    expect(find.text('مرخصی سالانه (روزانه)'), findsNWidgets(2));
    expect(find.text('از ۱۴۰۵/۰۷/۱۸ تا ۱۴۰۵/۰۷/۲۰'), findsOneWidget);
    expect(find.text('۳ روز'), findsOneWidget);
    expect(find.text('تهران'), findsWidgets);
    // LV-1404-0041: hourly, 4 hours.
    expect(find.text('LV-1404-0041'), findsOneWidget);
    expect(find.text('مرخصی استعلاجی (ساعتی)'), findsOneWidget);
    expect(find.text('۴ ساعت'), findsOneWidget);
  });

  testWidgets('a rejected leave card shows the rejection reason',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(
        tester,
        LeaveRequestsListPage(
            company: repository.company, repository: repository));
    await tester.tap(_tab('rejected'));
    await tester.pumpAndSettle();
    expect(find.text('LV-1404-0040'), findsOneWidget);
    expect(find.text('رد شده'), findsWidgets);
    expect(find.byKey(const ValueKey('leave-card-rejection')), findsOneWidget);
    expect(find.text('به دلیل مدارک ناقص'), findsOneWidget);
    // Approved and pending cards never show a reason.
    await tester.tap(_tab('all'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leave-card-rejection')), findsOneWidget);
  });

  testWidgets('«+» opens the template form', (tester) async {
    final repository = FakeRequestRepository();
    registerRequestTemplates();
    await _pump(
        tester,
        LeaveRequestsListPage(
            company: repository.company, repository: repository));
    await tester.tap(find.byTooltip('درخواست جدید'));
    await tester.pumpAndSettle();
    expect(find.byType(LeaveRequestFormPage), findsOneWidget);
  });

  test('requestListTabs are the four contract tabs', () {
    expect(requestListTabs.map((tab) => tab.$2),
        ['همه', 'در انتظار بررسی', 'تأیید شده', 'رد شده']);
  });
}
