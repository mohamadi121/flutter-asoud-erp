import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/employee/data/preview_hr_repository.dart';
import 'package:asoud_erp/features/employee/data/self_service_repository.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_home_page.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_attendance_page.dart';
import 'package:asoud_erp/features/workflows/data/demo/task_notification_demo_data.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeApiClient {}

class _Notifications extends Fake implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => true;

  @override
  Future<List<WorkflowNotification>> getNotifications(
          {bool unreadOnly = false}) async =>
      demoNotifications()
          .where((item) => !unreadOnly || !item.isRead)
          .toList(growable: false);

  @override
  Future<void> markRead(String notification) async {}
}

class _ThrowingHr extends Fake implements HrRepository {
  @override
  Future<HrDashboard> dashboard(String company) => throw UnimplementedError();
  @override
  Future<HrEmployee> myProfile() => throw UnimplementedError();
  @override
  Future<List<HrEmployee>> team({String query = ''}) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> organization(String company) =>
      throw UnimplementedError();
  @override
  Future<List<WorkReport>> reports() => throw UnimplementedError();
  @override
  Future<WorkReport> saveReport(WorkReport report) =>
      throw UnimplementedError();
  @override
  Future<List<HrCommunication>> communications({String box = 'inbox'}) =>
      throw UnimplementedError();
  @override
  Future<HrCommunication> sendCommunication(HrCommunication communication) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> notifications() =>
      throw UnimplementedError();
}

Widget _app(Widget page, {FrappeApiClient? client, HrRepository? hr}) =>
    RepositoryProvider<FrappeApiClient>.value(
      value: client ?? _Client(),
      child: RepositoryProvider<HrRepository>.value(
        value: hr ?? _ThrowingHr(),
        child: RepositoryProvider<WorkflowNotificationRepository>.value(
          value: _Notifications(),
          child: RepositoryProvider<WorkflowNotificationRepository?>.value(
            value: _Notifications(),
            child: MaterialApp(
                theme: AsoudTheme.light,
                home: Directionality(
                    textDirection: TextDirection.rtl, child: page)),
          ),
        ),
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  PreviewHrRepository previewHr() =>
      PreviewHrRepository(_ThrowingHr(), isPreview: () => true);

  for (final width in [320.0, 390.0]) {
    testWidgets('preview employee home greets and announces at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        const EmployeeHomePage(company: 'شرکت نمونه آسود', demoPreview: true),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.text('سلام سارا!'), findsOneWidget);
      expect(find.text('کارشناس فروش · فروش'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('کار جدید به شما ارجاع شد'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('کار جدید به شما ارجاع شد'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('مشاهده همه'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.tap(find.text('مشاهده همه'));
      await tester.pumpAndSettle();
      expect(find.text('اعلان‌ها'), findsWidgets);
      await tester.dragUntilVisible(
        find.text('تنخواه تیر تأیید شد'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('تنخواه تیر تأیید شد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview attendance shows history at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        MyAttendancePage(repository: SelfServiceRepository(client)),
        client: client,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('آخرین ثبت: ورود'), findsOneWidget);
      expect(find.text('حاضر'), findsWidgets);
      await tester.dragUntilVisible(
        find.text('مرخصی'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('مرخصی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview work reports show draft and feedback at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        const WorkReportsPage(company: 'شرکت نمونه آسود'),
        client: client,
        hr: previewHr(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('150 دقیقه • پیش‌نویس'), findsOneWidget);
      expect(find.text('300 دقیقه • ارسال‌شده'), findsOneWidget);
      expect(find.text('هنوز گزارش کاری ثبت نشده است'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview communications list the inbox at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        const HrCommunicationsPage(company: 'شرکت نمونه آسود'),
        client: client,
        hr: previewHr(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('جلسه هماهنگی فروش'), findsOneWidget);
      expect(find.text('تحویل اسناد تنخواه'), findsOneWidget);
      expect(find.text('احمد رضایی • زیاد'), findsOneWidget);
      expect(find.text('مکاتبه‌ای برای نمایش وجود ندارد'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview HR notifications list five items at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        const HrNotificationsPage(company: 'شرکت نمونه آسود'),
        client: client,
        hr: previewHr(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مرخصی شما تأیید شد'), findsOneWidget);
      expect(find.text('اعلان جدیدی وجود ندارد'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
