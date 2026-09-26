import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_home_page.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_shell.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_attendance_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
  Future<void> checkin(String logType) async => calls.add(logType);
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

Widget _app(Widget page) => RepositoryProvider<FrappeApiClient>.value(
      value: _Client(),
      child: MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(textDirection: TextDirection.rtl, child: page)),
    );

void main() {
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
      expect(find.text('سلام امیر!'), findsOneWidget);
      expect(find.text('کارشناس فروش · فروش'), findsOneWidget);
      expect(find.textContaining('۱۴۰'), findsWidgets);
      for (final label in [
        'درخواست‌ها',
        'حضور و غیاب',
        'گزارش کار',
        'مکاتبات',
        'اطلاعات من',
        'مدارک'
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('۳'), findsOneWidget); // unread notifications badge
      expect(find.text('۲'), findsOneWidget); // open requests badge
      await tester.ensureVisible(find.text('جلسه عمومی'));
      expect(find.text('جلسه عمومی'), findsOneWidget);
      await tester.tap(find.text('درخواست‌ها'));
      expect(opened, [2]);
      await tester.tap(find.text('اطلاعات من'));
      await tester.pumpAndSettle();
      expect(find.byType(PersonnelFilePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shell shows the five destinations and the more tab',
      (tester) async {
    await tester.pumpWidget(_app(EmployeeShell(
        company: 'Tabaan', files: _Files(), selfService: _SelfService())));
    await tester.pumpAndSettle();
    for (final label in ['خانه', 'کارتابل', 'درخواست‌ها', 'مکاتبات', 'بیشتر']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget,
          reason: label);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'بیشتر'));
    await tester.pumpAndSettle();
    for (final label in ['اطلاعات من', 'مدارک من', 'اطلاعیه‌ها']) {
      expect(find.text(label), findsOneWidget, reason: label);
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
