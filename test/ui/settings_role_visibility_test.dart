import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

const adminTiles = [
  'مدیریت کاربران',
  'ساختار سازمانی',
  'ماژول‌ها',
  'انواع درخواست',
  'مدیریت نقش‌ها',
  'گردش کار',
];

void main() {
  testWidgets('hr-manager sees no admin tile and keeps the HR tile at 390 px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(settingsApp(const ['HR Manager', 'Employee']));
    await tester.pumpAndSettle();
    for (final tile in adminTiles) {
      expect(find.text(tile), findsNothing,
          reason: 'HR Manager must not see the admin tile «$tile»');
    }
    expect(find.text('منابع انسانی'), findsOneWidget);
    expect(find.text('ثبت درخواست‌ها'), findsOneWidget);
    expect(find.text('کارتابل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator sees every admin tile and the HR tile at 390 px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(settingsApp(const [
      'System Manager',
      'Accounts Manager',
      'HR Manager',
      'Employee',
    ]));
    await tester.pumpAndSettle();
    for (final tile in adminTiles) {
      expect(find.text(tile), findsOneWidget,
          reason: 'Administrator must see the admin tile «$tile»');
    }
    expect(find.text('منابع انسانی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}