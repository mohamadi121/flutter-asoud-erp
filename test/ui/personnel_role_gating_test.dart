import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Roles extends Fake implements FrappeApiClient {
  _Roles(this.roles);
  final List<String> roles;
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: roles.contains('System Manager')
            ? 'Administrator@asoud-demo.local'
            : 'hr-manager@asoud-demo.local',
        fullName: roles.contains('System Manager')
            ? 'مدیر سیستم'
            : 'مدیر منابع انسانی',
        roles: roles,
      );
}

class _People extends Fake implements PersonnelRepository {
  final profile = <String, dynamic>{
    'id': 'PARTY-1',
    'display_name': 'سارا کریمی',
    'job_title': 'کارشناس فروش',
    'department': 'فروش',
    'employment_type': 'تمام وقت',
    'employee_code': 'EMP-42',
    'mobile': '09121234567',
  };

  @override
  void dispose() {}
  @override
  bool get localDemo => false;
  @override
  Future<Map<String, dynamic>> list(String company) async => {
        'rows': [profile],
        'can_edit': true,
      };
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'profile': profile,
        'records': <Map<String, dynamic>>[],
        'revision': '1',
        'can_edit': true,
      };
}

Widget _app(Widget page, FrappeApiClient client) => MultiRepositoryProvider(
      providers: [RepositoryProvider<FrappeApiClient>.value(value: client)],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

void main() {
  testWidgets('پرسنل: مدیر منابع انسانی کنترل‌های نوشتن را نمی‌بیند',
      (tester) async {
    final client = _Roles(const ['HR Manager', 'Employee']);
    await tester.pumpWidget(_app(
        PersonnelPage(company: 'دفتر نمونه', repository: _People()), client));
    await tester.pumpAndSettle();

    expect(find.text('سارا کریمی'), findsOneWidget);
    expect(find.byTooltip('افزودن پرسنل'), findsNothing);
    expect(find.byTooltip('مدیریت دسترسی'), findsNothing);
    expect(find.text('مدیریت و پیشنهاد پرسنل نمونه'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('پرسنل: مدیر منابع انسانی در $width بدون سرریز', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Roles(const ['HR Manager', 'Employee']);
      await tester.pumpWidget(_app(
          PersonnelPage(company: 'دفتر نمونه', repository: _People()), client));
      await tester.pumpAndSettle();

      expect(find.text('سارا کریمی'), findsOneWidget);
      expect(find.byTooltip('افزودن پرسنل'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('پرسنل: مدیر سیستم کنترل‌های نوشتن را می‌بیند', (tester) async {
    final client = _Roles(const [
      'System Manager',
      'Accounts Manager',
      'HR Manager',
      'Employee',
    ]);
    await tester.pumpWidget(_app(
        PersonnelPage(company: 'دفتر نمونه', repository: _People()), client));
    await tester.pumpAndSettle();

    expect(find.text('سارا کریمی'), findsOneWidget);
    expect(find.byTooltip('افزودن پرسنل'), findsOneWidget);
    expect(find.byTooltip('مدیریت دسترسی'), findsOneWidget);
  });

  testWidgets('پرونده: مدیر منابع انسانی بدون ویرایش و انتقال', (tester) async {
    final client = _Roles(const ['HR Manager', 'Employee']);
    await tester.pumpWidget(_app(
        PersonnelDetailPage(id: 'PARTY-1', repository: _People()), client));
    await tester.pumpAndSettle();

    expect(find.text('سارا کریمی'), findsWidgets);
    expect(find.text('ویرایش اطلاعات'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('انتقال سوابق پرسنل محلی'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('انتقال سوابق پرسنل محلی'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('پرونده: مدیر سیستم ویرایش و انتقال را می‌بیند', (tester) async {
    final client = _Roles(const [
      'System Manager',
      'Accounts Manager',
      'HR Manager',
      'Employee',
    ]);
    await tester.pumpWidget(_app(
        PersonnelDetailPage(id: 'PARTY-1', repository: _People()), client));
    await tester.pumpAndSettle();

    expect(find.text('ویرایش اطلاعات'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('انتقال سوابق پرسنل محلی'), findsOneWidget);
  });
}