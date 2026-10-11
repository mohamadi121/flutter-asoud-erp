import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request.dart';
import 'package:asoud_erp/features/purchase/domain/purchase_request_repository.dart';
import 'package:asoud_erp/features/purchase/presentation/pages/purchase_request_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationRepository implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowNotification>> getNotifications(
      {bool unreadOnly = false}) async {
    return [
      WorkflowNotification(
        id: 'NOTIF-1',
        title: 'کار جدید در گردش‌کار',
        message: 'درخواست مرخصی بهنام عزیزی',
        instance: 'WFI-1',
        isRead: false,
        createdAt: DateTime(2026, 10, 7, 2, 12),
      ),
    ];
  }

  @override
  Future<void> markRead(String notification) async {}
}

class _FakePurchaseRepository implements PurchaseRequestRepository {
  @override
  Future<List<PurchaseRequestSummary>> list(String company) async => [];

  @override
  Future<PurchaseRequestOptions> options(String company) async =>
      const PurchaseRequestOptions(
        warehouses: ['انبار مرکزی'],
        items: [
          PurchaseItemOption(code: 'ITM-1', name: 'کاغذ A4', uom: 'بسته')
        ],
      );

  @override
  Future<PurchaseRequestResult> create({
    required String company,
    required String subject,
    required DateTime scheduleDate,
    required List<PurchaseRequestLine> items,
  }) async =>
      const PurchaseRequestResult(
        name: 'PR-1',
        workflowInstance: 'WFI-1',
        localOnly: false,
      );
}

void main() {
  testWidgets(
      'اعلان‌ها زمان را به صورت جلالی و ارقام فارسی نشان می‌دهند (نه میلادی)',
      (tester) async {
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

    // Should NOT find Gregorian format: '2026/10/07 – 02:12'
    expect(find.textContaining('2026/10/07'), findsNothing);
    // MUST find Jalali format: '۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲'
    expect(find.text('۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲'), findsOneWidget);
  });

  testWidgets(
      'فرم درخواست خرید تاریخ نیاز پیش‌فرض را به جلالی نشان می‌دهد (نه میلادی)',
      (tester) async {
    final repo = _FakePurchaseRepository();
    await tester.pumpWidget(
      RepositoryProvider<PurchaseRequestRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: PurchaseRequestPage(company: 'شرکت نمونه'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Gregorian year 2026 must NOT appear in the date field
    expect(find.textContaining('2026/'), findsNothing);
    // Jalali year ۱۴۰۵ must appear
    expect(find.textContaining('۱۴۰۵/'), findsOneWidget);
  });
}
