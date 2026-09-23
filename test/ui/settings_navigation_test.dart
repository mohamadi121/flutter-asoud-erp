import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget page) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: page));

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('settings layout and base setup route at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(
          const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true)));
      await tester.tap(find.text('تنظیمات'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDashboardContent), findsOneWidget);
      expect(find.text('۱۲۴'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0;
          i < 12 && find.text('تنظیمات پایه').hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('تنظیمات پایه'));
      await tester.pumpAndSettle();
      expect(find.byType(BaseAccountingSetupPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('گزارش‌ها'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDashboardContent), findsNothing);
      expect(find.text('دفتر کار'), findsOneWidget);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings remains accessible before office creation',
      (tester) async {
    await tester.pumpWidget(app(const DashboardPage()));
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDashboardContent), findsOneWidget);
    expect(find.text('انتخاب دفتر'), findsOneWidget);
    expect(find.text('مدیریت کاربران'),
        findsNothing); // Below the initial viewport.
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('گزارش‌ها'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDashboardContent), findsNothing);
  });
}
