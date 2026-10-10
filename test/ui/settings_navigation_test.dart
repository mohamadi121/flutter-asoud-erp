import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_role_client.dart';

class _SettingsClient extends Fake implements FrappeApiClient {
  _SettingsClient(this.roles);
  final List<String> roles;
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'user@asoud-demo.local',
        fullName: roles.contains('System Manager')
            ? 'مدیر سیستم'
            : 'مدیر منابع انسانی',
        roles: roles,
      );
}

Widget settingsApp(List<String> roles) => RepositoryProvider<FrappeApiClient>.value(
    value: _SettingsClient(roles),
    child: MaterialApp(
        theme: AsoudTheme.light,
        home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsDashboardContent(company: 'دفتر نمونه'))));

Widget app(Widget page, {FrappeApiClient? client}) =>
    RepositoryProvider<FrappeApiClient>.value(
        value: client ?? FakeRoleClient(),
        child: MaterialApp(
            theme: AsoudTheme.light,
            home:
                Directionality(textDirection: TextDirection.rtl, child: page)));

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('settings layout, roles and base setup routes at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = FakeRoleClient();
      await tester.pumpWidget(app(
          const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true),
          client: client));
      await tester.tap(find.text('تنظیمات'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDashboardContent), findsOneWidget);
      expect(find.text('۱۲۴'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0;
          i < 12 && find.text('مدیریت نقش‌ها').hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('مدیریت نقش‌ها'));
      await tester.pumpAndSettle();
      expect(find.byType(RolesPage), findsOneWidget);
      expect(find.text('مشاهده و تکمیل نقش‌ها'), findsOneWidget);
      expect(client.methods, ['asoud_erp.api.v1.role_management.catalog']);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      // Base setup remains available through Modules, not the renamed role card.
      await tester.ensureVisible(find.text('ماژول‌ها'));
      await tester.tap(find.text('ماژول‌ها'));
      await tester.pumpAndSettle();
      expect(find.byType(BaseAccountingSetupPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('گزارش‌ها'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDashboardContent), findsNothing);
      expect(find.text('گزارش‌ها'), findsOneWidget);
      expect(find.text('به‌زودی'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings remains accessible before office creation',
      (tester) async {
    await tester.pumpWidget(app(
        const DashboardPage(),
        client: _SettingsClient(const [
          'System Manager',
          'Accounts Manager',
          'HR Manager',
          'Employee',
        ])));
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDashboardContent), findsOneWidget);
    expect(find.text('انتخاب دفتر'), findsOneWidget);
    // The system-status cards are hidden outside the offline preview, so the
    // actions grid now fits inside the initial viewport.
    expect(find.text('مدیریت کاربران'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('گزارش‌ها'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDashboardContent), findsOneWidget);
  });

  testWidgets('payment and sales quick actions open their destinations',
      (tester) async {
    await tester.pumpWidget(
      app(const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true)),
    );
    await tester.pumpAndSettle();

    for (final title in ['دریافت و پرداخت', 'فاکتور فروش']) {
      await tester.dragUntilVisible(
        find.text(title),
        find.byType(Scrollable).first,
        const Offset(0, -180),
      );
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('به‌زودی'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('hr-manager sees no administrative settings tile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(settingsApp(const ['HR Manager', 'Employee']));
    await tester.pumpAndSettle();
    for (final tile in [
      'مدیریت کاربران',
      'ساختار سازمانی',
      'ماژول‌ها',
      'انواع درخواست',
      'مدیریت نقش‌ها',
      'گردش کار',
    ]) {
      expect(find.text(tile), findsNothing);
    }
    for (final tile in ['دفترها', 'منابع انسانی', 'ثبت درخواست‌ها', 'کارتابل']) {
      expect(find.text(tile), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator keeps the administrative settings tiles',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(settingsApp(const [
      'System Manager',
      'Accounts Manager',
      'HR Manager',
      'Employee',
    ]));
    await tester.pumpAndSettle();
    for (final tile in [
      'مدیریت کاربران',
      'ساختار سازمانی',
      'ماژول‌ها',
      'انواع درخواست',
      'مدیریت نقش‌ها',
      'گردش کار',
    ]) {
      expect(find.text(tile), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
