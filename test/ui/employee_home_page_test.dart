import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/data/account_repository.dart';
import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';
import 'package:asoud_erp/features/auth/presentation/pages/admin_profile_page.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_home_page.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_shell.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_attendance_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_info_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_account_repository.dart';

class _Client extends Mock implements FrappeApiClient {}

class _Files extends Fake implements PersonnelFileRepository {
  @override
  Future<EmployeeHome> myHome() async => EmployeeHome.fromJson({
        'profile_id': 'PARTY-1',
        'employee': 'HR-EMP-00042',
        'name': 'امیر موفق',
        'designation': 'کارشناس فروش',
        'department_name': 'فروش',
        'company': 'Tabaan',
        'date': '2026-09-25',
        'counts': {
          'open_requests': 2,
          'open_tasks': 1,
          'unread_notifications': 3,
          'pending_leave_applications': 0,
          'leave_remaining': 8,
        },
        'announcements': [
          {
            'name': 'N1',
            'title': 'جلسه عمومی',
            'summary': 'پنجشنبه ساعت ۱۰ در سالن اجتماعات',
            'date': '2026-09-24 09:00:00',
          }
        ],
      });

  @override
  Future<PersonnelFile> myFile() async => PersonnelFile.fromJson({
        'profile_id': 'PARTY-1',
        'header': {'name': 'امیر موفق', 'employee_code': 'HR-EMP-00042'},
      });

  @override
  Future<List<Announcement>> announcements() async => [];
}

class _SelfService extends Fake implements SelfServiceRepository {
  final calls = <String>[];
  @override
  Future<CheckinResult> checkin(String logType) async {
    calls.add(logType);
    return CheckinResult.accepted;
  }

  @override
  Future<List<Map<String, dynamic>>> checkins(
          {String? fromDate, String? toDate}) async =>
      [
        {'log_type': 'IN', 'time': '2026-09-25 08:02:00'}
      ];
  @override
  Future<List<Map<String, dynamic>>> attendance(
          String fromDate, String toDate) async =>
      [
        {'attendance_date': '2026-09-24', 'status': 'Present'}
      ];
}

class _AdminFiles extends _Files {
  _AdminFiles(this.accounts);
  final FakeAccountRepository accounts;
  String get _name => accounts.lastSave.isEmpty ? 'مریم احمدی'
      : "${accounts.lastSave['first']} ${accounts.lastSave['last']}";

  @override
  Future<EmployeeHome> myHome() async => EmployeeHome.fromJson({
    'profile_id': 'PERSON-ADMIN', 'admin_identity': true, 'name': _name,
    'designation': 'مدیر کل سیستم', 'company': 'Tabaan',
  });

  @override
  Future<PersonnelFile> myFile() async => PersonnelFile.fromJson({
    'profile_id': 'PERSON-ADMIN', 'admin_identity': true, 'can_edit': true,
    'header': {'name': _name, 'designation': 'مدیر کل سیستم', 'company': 'Tabaan'},
    'personal': {'father_name': accounts.lastSave['father_name'] ?? ''},
  });
}

Widget _app(Widget page, {AccountRepository? accounts}) {
  final client = _Client();
  when(() => client.isAuthenticated).thenReturn(false);
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: client),
      if (accounts != null) RepositoryProvider<AccountRepository>.value(value: accounts),
    ],
    child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: page)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('administrator opens and updates their own file from the home card', (tester) async {
    final accounts = FakeAccountRepository(
      state: const LoginState(userId: 'Administrator', isSystemAdmin: true),
      profile: const AccountProfile(username: 'Administrator', firstName: 'مریم',
          lastName: 'احمدی', mobile: '09123456789'),
    );
    await tester.pumpWidget(_app(Scaffold(body: EmployeeHomePage(
      company: 'Tabaan', files: _AdminFiles(accounts), selfService: _SelfService(),
    )), accounts: accounts));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مریم احمدی'));
    await tester.pumpAndSettle();
    expect(find.byType(MyInfoPage), findsOneWidget);
    expect(find.text('کد پرسنلی'), findsNothing);
    await tester.tap(find.text('ویرایش'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProfilePage), findsOneWidget);
    await tester.enterText(find.byKey(const Key('last_name')), 'احمدی نیا');
    final father = find.byKey(const ValueKey('admin_father_name'));
    await tester.scrollUntilVisible(father, 160, scrollable: find.byType(Scrollable).first);
    await tester.enterText(father, 'علی');
    await tester.tap(find.byKey(const Key('profile_submit')));
    await tester.pumpAndSettle();
    expect(accounts.lastSave['father_name'], 'علی');
    expect(find.byType(MyInfoPage), findsOneWidget);
    expect(find.text('مریم احمدی نیا'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('مریم احمدی نیا'), findsOneWidget);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('employee home at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final opened = <int>[];
      await tester.pumpWidget(_app(Scaffold(
          body: EmployeeHomePage(
              company: 'Tabaan',
              files: _Files(),
              selfService: _SelfService(),
              onOpenTab: opened.add))));
      await tester.pumpAndSettle();
      expect(find.text('آسود'), findsOneWidget);
      expect(find.text('خانه من'), findsOneWidget);
      expect(find.text('امیر موفق'), findsOneWidget);
      expect(find.text('کارشناس فروش · فروش'), findsOneWidget);
      expect(find.textContaining('۱۴۰'), findsWidgets);
      expect(find.text('برنامه هفتگی من'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('۳')),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('نیازمند اقدام من'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('نیازمند اقدام من'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('عملیات'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('عملیات'));
      await tester.pumpAndSettle();
      for (final label in [
        'درخواست‌ها',
        'حضور و غیاب',
        'گزارش کار',
        'مکاتبات',
        'پرونده من',
        'مدارک'
      ]) {
        await tester.scrollUntilVisible(find.text(label), 150,
            scrollable: find.byType(Scrollable).first);
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(find.text('درخواست‌ها'), -150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(Badge), matching: find.text('۲')),
          findsOneWidget);
      await tester.tap(find.text('درخواست‌ها'));
      expect(opened, [2]);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('پرونده من'), -150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('پرونده من'));
      await tester.pumpAndSettle();
      expect(find.byType(MyInfoPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shell shows the five destinations and the more tab',
      (tester) async {
    await tester.pumpWidget(_app(EmployeeShell(
        company: 'Tabaan', files: _Files(), selfService: _SelfService())));
    await tester.pumpAndSettle();
    for (final label in ['خانه', 'عملیات', 'ایجاد', 'کارتابل', 'بیشتر']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget,
          reason: label);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'بیشتر'));
    await tester.pumpAndSettle();
    for (final label in ['کارتابل', 'پرونده من', 'مدارک من', 'اطلاعیه‌ها']) {
      expect(find.widgetWithText(ListTile, label), findsOneWidget,
          reason: label);
    }
    await tester.tap(find.text('حضور و غیاب'));
    await tester.pumpAndSettle();
    expect(find.byType(MyAttendancePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance page records a check-in', (tester) async {
    final service = _SelfService();
    await tester.pumpWidget(_app(
        MyAttendancePage(repository: service, today: DateTime(2026, 9, 25))));
    await tester.pumpAndSettle();
    expect(find.text('حاضر'), findsOneWidget);
    expect(find.textContaining('آخرین ثبت: ورود'), findsOneWidget);
    await tester.tap(find.text('ثبت ورود'));
    await tester.pumpAndSettle();
    expect(service.calls, ['IN']);
    expect(find.text('ورود ثبت شد.'), findsOneWidget);
  });
}
