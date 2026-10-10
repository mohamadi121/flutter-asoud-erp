import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationRepository extends Fake implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowNotification>> getNotifications({bool unreadOnly = false}) async => [
        WorkflowNotification(
          id: 'NOTIF-1',
          title: 'New workflow task: Approval',
          message: 'درخواست مرخصی برای بررسی ارجاع شد.',
          instance: 'WFI-001',
          isRead: false,
          createdAt: DateTime(2026, 10, 10, 10, 30),
        ),
        WorkflowNotification(
          id: 'NOTIF-2',
          title: 'Workflow request approved',
          message: 'درخواست شما با موفقیت تأیید شد.',
          instance: 'WFI-002',
          isRead: true,
          createdAt: DateTime(2026, 10, 10, 9, 15),
        ),
      ];

  @override
  Future<void> markRead(String id) async {}
}

void main() {
  group('T2: Server Values Persian Localization (Bugs #13, #14, #15, #19)', () {
    test('workflow stage names and types translate correctly', () {
      expect(persianWorkflowStageTitle('Start'), 'شروع');
      expect(persianWorkflowStageTitle('User Task'), 'وظیفه کاربر');
      expect(persianWorkflowStageTitle('Approval'), 'تأیید');
      expect(persianWorkflowStageTitle('System Action'), 'اقدام خودکار');
      expect(persianWorkflowStageTitle('End'), 'پایان');
      expect(persianWorkflowStageTitle('Condition'), 'شرط');
      expect(persianWorkflowStageTitle('Wait'), 'انتظار');
    });

    test('leave types map to exact Persian official terms', () {
      expect(persianLeaveTypeLabel('Casual Leave'), 'مرخصی اتفاقی');
      expect(persianLeaveTypeLabel('Compensatory Off'), 'مرخصی جبرانی');
      expect(persianLeaveTypeLabel('Leave Without Pay'), 'مرخصی بدون حقوق');
      expect(persianLeaveTypeLabel('Privilege Leave'), 'مرخصی استحقاقی');
      expect(persianLeaveTypeLabel('Sick Leave'), 'مرخصی استعلاجی');
    });

    test('ERPNext role names map codes like HR_MANAGER to Persian title and keep unknown', () {
      expect(persianRoleLabel('HR_MANAGER'), 'مدیر منابع انسانی');
      expect(persianRoleLabel('hr_manager'), 'مدیر منابع انسانی');
      expect(persianRoleLabel('SYSTEM_MANAGER'), 'مدیر سیستم');
      expect(persianRoleLabel('ACCOUNTS_MANAGER'), 'مدیر مالی');
      expect(persianRoleLabel('ACCOUNTS_USER'), 'کارشناس مالی');
      expect(persianRoleLabel('EMPLOYEE'), 'کارمند');
      expect(persianRoleLabel('UNKNOWN_TEST_ROLE'), 'UNKNOWN_TEST_ROLE');
    });

    test('notification titles built by server in English translate with patterns', () {
      expect(
        persianNotificationTitle('New workflow task: Approval'),
        'کار جدید در گردش‌کار: تأیید',
      );
      expect(
        persianNotificationTitle('New workflow task: User Task'),
        'کار جدید در گردش‌کار: وظیفه کاربر',
      );
      expect(
        persianNotificationTitle('Workflow request approved'),
        'درخواست گردش‌کار تأیید شد',
      );
      expect(
        persianNotificationTitle('Workflow request rejected'),
        'درخواست گردش‌کار رد شد',
      );
      expect(
        persianNotificationTitle('Workflow request returned'),
        'درخواست گردش‌کار بازگردانده شد',
      );
    });

    test('request and task statuses translate to Persian', () {
      expect(persianWorkflowStatus('Running'), 'در حال گردش');
      expect(persianWorkflowStatus('Completed'), 'تکمیل‌شده');
      expect(persianWorkflowStatus('Rejected'), 'ردشده');
      expect(persianWorkflowStatus('Cancelled'), 'لغوشده');
      expect(persianWorkflowStatus('Open'), 'در انتظار اقدام');
      expect(persianWorkflowStatus('Draft'), 'پیش‌نویس');
      expect(persianWorkflowStatus('Approved'), 'تأییدشده');
    });

    test('technical document fields and doctypes translate to Persian', () {
      expect(persianDocumentFieldLabel('Company'), 'شرکت');
      expect(persianDocumentFieldLabel('Workflow'), 'گردش‌کار');
      expect(persianDocumentFieldLabel('Request Type'), 'نوع درخواست');
      expect(persianDocumentFieldLabel('Subject'), 'موضوع');
      expect(persianDocumentFieldLabel('Priority'), 'اولویت');
      expect(persianDocumentFieldLabel('Status'), 'وضعیت');
      expect(persianDoctypeLabel('ASOUD Workflow Request'), 'درخواست گردش‌کار');
      expect(persianDoctypeLabel('Material Request'), 'درخواست کالا / خرید');
      expect(persianDoctypeLabel('Leave Application'), 'درخواست مرخصی');
    });

    testWidgets('notification page renders server titles in translated Persian at 320 and 390 px',
        (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _FakeNotificationRepository();
        await tester.pumpWidget(
          RepositoryProvider<WorkflowNotificationRepository>.value(
            value: repo,
            child: MaterialApp(
              theme: AsoudTheme.light,
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: WorkflowNotificationsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must NOT leak English server titles
        expect(find.text('New workflow task: Approval'), findsNothing);
        expect(find.text('Workflow request approved'), findsNothing);

        // Concrete Persian translated titles
        expect(find.text('کار جدید در گردش‌کار: تأیید'), findsOneWidget);
        expect(find.text('درخواست گردش‌کار تأیید شد'), findsOneWidget);
      }
    });
  });
}
