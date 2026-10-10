import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/states.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/accounting_home_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget page) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: page));

void main() {
  testWidgets('dead accounting rows are dimmed with a coming-soon badge',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(const AccountingHomePage()));

    // The five unimplemented rows carry the «به‌زودی» badge (bug #11).
    expect(find.text('به‌زودی'), findsNWidgets(5));

    // «سرفصل حساب‌ها» has no company here, so it is dimmed without a badge.
    expect(find.text('سرفصل حساب‌ها'), findsOneWidget);

    // Tapping an inert row must not navigate or throw.
    await tester.tap(find.text('سند حسابداری'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountingHomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard hides empty KPI cards outside the offline preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(const DashboardPage()));
    await tester.pump();

    // «—» + «پس از اتصال سرور» placeholders must not be shown as real data.
    expect(find.text('دریافتی امروز'), findsNothing);
    expect(find.text('پس از اتصال سرور'), findsNothing);
  });

  testWidgets('a coming-soon destination uses the shared state widget',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        _wrap(const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true)));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('دریافت و پرداخت'),
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.tap(find.text('دریافت و پرداخت'));
    await tester.pumpAndSettle();

    expect(find.byType(ComingSoonState), findsOneWidget);
    expect(find.text('به‌زودی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
