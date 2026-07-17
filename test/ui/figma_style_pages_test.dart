import 'package:asoud_erp/core/theme/asoud_theme.dart';
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

Widget _app(Widget page) => RepositoryProvider<OfficeRepository>.value(
      value: FakeOfficeRepository(),
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

void main() {
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
    await tester.pumpWidget(_app(const DashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('وضعیت اتصال ERPNext'), findsOneWidget);
    expect(find.text('عملیات سریع'), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('گزارش‌ها'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  final pages = <String, Widget>{
    'تنظیمات پایه': const BaseAccountingSetupPage(),
    'نقش‌های اولیه': const RolesSetupPage(),
    'خانه حسابداری': const AccountingHomePage(),
    'سرفصل حساب‌ها': const ChartOfAccountsPage(),
    'فرم حساب': const AccountFormPage(),
  };
  for (final entry in pages.entries) {
    testWidgets('${entry.key} در اندازه مرجع بدون خطای چیدمان باز می‌شود',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(_app(entry.value));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  }
}
