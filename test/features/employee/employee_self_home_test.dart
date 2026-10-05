import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_home_page.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_shell.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_info_page.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_attendance_page.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_info_page_test.dart' show Files, app;

class HomeFiles extends Files {
  HomeFiles({this.checkin});
  final String? checkin;
  @override
  Future<EmployeeHome> myHome() async => EmployeeHome.fromJson({
        'name': 'امیر موفق',
        'designation': 'کارشناس',
        'department_name': 'فروش',
        if (checkin != null)
          'last_checkin': {'time': checkin, 'log_type': 'IN'},
      });
}

class Notifications extends Fake implements WorkflowNotificationRepository {
  @override
  Future<List<WorkflowNotification>> getNotifications(
          {bool unreadOnly = false}) async =>
      List.generate(
          5,
          (i) => WorkflowNotification(
              id: '$i',
              title: 'اعلان $i',
              message: 'متن $i',
              isRead: i == 4,
              createdAt: DateTime(2026, 10, 5, 8 + i)));
}

class Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
}

class Hr extends Fake implements HrRepository {
  @override
  Future<List<WorkReport>> reports() async => [];
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) async =>
      [];
}

class SelfService extends Fake implements SelfServiceRepository {
  @override
  Future<List<Map<String, dynamic>>> checkins(
          {String? fromDate, String? toDate}) async =>
      [];
  @override
  Future<List<Map<String, dynamic>>> attendance(
          String fromDate, String toDate) async =>
      [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('today status ignores yesterday and shows today check-in',
      (tester) async {
    for (final day in [4, 5]) {
      await tester.pumpWidget(app(Scaffold(
          body: EmployeeHomePage(
              company: 'شرکت',
              files: HomeFiles(checkin: '2026-10-0$day 08:12:00'),
              now: DateTime(2026, 10, 5)))));
      await tester.pumpAndSettle();
      expect(
          find.text(
              day == 5 ? 'ورود امروز: ۰۸:۱۲' : 'امروز هنوز ورودی ثبت نشده'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('each home tile opens its actual destination', (tester) async {
    final destinations = {
      'درخواست‌ها': GenericRequestsPage,
      'حضور و غیاب': MyAttendancePage,
      'گزارش کار': WorkReportsPage,
      'مکاتبات': HrCommunicationsPage,
      'اطلاعات من': MyInfoPage,
      'مدارک': MyInfoPage
    };
    for (final entry in destinations.entries) {
      await tester.pumpWidget(MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FrappeApiClient>.value(value: Client()),
            RepositoryProvider<HrRepository>.value(value: Hr())
          ],
          child: app(Scaffold(
              body: EmployeeHomePage(
                  company: 'شرکت',
                  files: HomeFiles(),
                  selfService: SelfService(),
                  notifications: Notifications())))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      if (entry.key == 'مدارک') expect(find.text('کارت ملی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
  testWidgets('shell four destinations retains tasks and announcements in More',
      (tester) async {
    await tester.pumpWidget(app(EmployeeShell(
        company: 'شرکت', files: HomeFiles(), selfService: SelfService())));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final label in ['خانه', 'درخواست‌ها', 'مکاتبات', 'بیشتر']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'بیشتر'));
    await tester.pumpAndSettle();
    for (final label in [
      'کارتابل',
      'اطلاعیه‌ها',
      'اعلان‌ها',
      'مدارک من',
      'اطلاعات من',
      'حضور و غیاب',
      'گزارش کار'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('اطلاعات من'));
    await tester.pumpAndSettle();
    expect(find.byType(MyInfoPage), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('home greeting date six tiles latest three at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(Scaffold(
          body: EmployeeHomePage(
              company: 'شرکت',
              files: HomeFiles(),
              notifications: Notifications(),
              now: DateTime(2026, 10, 5, 13)))));
      await tester.pumpAndSettle();
      expect(find.text('سلام امیر!'), findsOneWidget);
      expect(find.text('روز خوبی داشته باشی'), findsOneWidget);
      expect(find.text('امیر موفق'), findsOneWidget);
      expect(
          find.text(formatJalaliLong(DateTime(2026, 10, 5))), findsOneWidget);
      expect(find.text('امروز هنوز ورودی ثبت نشده'), findsOneWidget);
      for (final title in [
        'درخواست‌ها',
        'حضور و غیاب',
        'گزارش کار',
        'مکاتبات',
        'اطلاعات من',
        'مدارک',
        'ثبت و پیگیری درخواست',
        'ثبت ورود و خروج',
        'ثبت گزارش روزانه',
        'دریافت و ارسال نامه',
        'مشاهده پرونده',
        'مشاهده مدارک'
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      for (final i in [4, 3, 2]) {
        expect(find.text('اعلان $i'), findsOneWidget);
      }
      expect(find.text('اعلان 1'), findsNothing);
      expect(find.text('اعلان 0'), findsNothing);
      expect(find.byKey(const ValueKey('unread-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-4')), findsNothing);
      expect(find.text('۱ ساعت پیش'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
