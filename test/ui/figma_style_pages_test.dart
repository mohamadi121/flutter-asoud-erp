import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/account_form_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/accounting_home_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_of_accounts_page.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/roles_setup_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_type_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';

import '../helpers/fake_office_repository.dart';
import '../helpers/fake_role_client.dart';

Widget _app(Widget page) => RepositoryProvider<OfficeRepository>.value(
      value: FakeOfficeRepository(),
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: page is RolesSetupPage
                ? RepositoryProvider<FrappeApiClient>.value(
                    value: FakeRoleClient(), child: page)
                : page),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
        'صفحه انتخاب دفتر در عرض $width بدون خطای چیدمان نمایش داده می‌شود',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(_app(const OfficeTypePage()));
      await tester.pumpAndSettle();

      expect(find.text('ایجاد دفتر کار'), findsNWidgets(2));
      expect(find.text('شخص حقیقی'), findsOneWidget);
      expect(find.text('شخص حقوقی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('داشبورد اجزای اصلی متناظر با طرح را نمایش می‌دهد',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    // A fixed clock: the home calendar changes height with the weekday and
    // holidays, which decides whether the quick-access grid is built yet.
    await tester.pumpWidget(_app(DashboardPage(
        officeName: 'شرکت نمونه', now: DateTime(2026, 10, 5))));
    await tester.pumpAndSettle();

    expect(find.text('آسود'), findsOneWidget);
    expect(find.text('خانه من'), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    await tester.dragUntilVisible(find.text('دسترسی سریع'),
        find.byType(Scrollable).first, const Offset(0, -200));
    // One «عملیات» in the bottom bar and one quick-access tile.
    expect(find.text('عملیات'), findsNWidgets(2));
    expect(
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('عملیات')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('داشبورد پیش از ایجاد دفتر در وضعیت خام نمایش داده می‌شود',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_app(const DashboardLandingPage()));
    await tester.pumpAndSettle();
    expect(find.text('شروع ایجاد دفتر'), findsOneWidget);
    expect(find.text('مشاهده راهنما'), findsOneWidget);
    expect(find.text('دریافتی امروز'), findsNothing);
    expect(find.text('عملیات سریع'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  final pages = <String, Widget>{
    'تنظیمات پایه': const BaseAccountingSetupPage(),
    'مدیریت نقش‌ها': const RolesSetupPage(),
    'خانه حسابداری': const AccountingHomePage(),
    'سرفصل حساب‌ها': const ChartOfAccountsPage(),
    'فرم حساب': const AccountFormPage(),
  };
  for (final entry in pages.entries) {
    testWidgets('${entry.key} در اندازه مرجع بدون خطای چیدمان باز می‌شود',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(entry.value));
      await tester.pumpAndSettle();
      if (entry.value is RolesSetupPage) {
        expect(find.text('مدیریت نقش‌ها'), findsOneWidget);
        expect(find.text('مشاهده و تکمیل نقش‌ها'), findsOneWidget);
        expect(find.text('ورود از اکسل'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
