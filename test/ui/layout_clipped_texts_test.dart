import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_attachments.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_form_controller.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_instance_detail_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_tasks_page.dart';

void main() {
  group('T1: Clipped texts regression tests at 320 px RTL', () {
    testWidgets('CapRows wraps long labels and values with Tooltip and maxLines at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CapRows(values: {
                'تاریخ شروع': '۱۴۰۱/۰۳/۱۱',
                'زمان باقی‌مانده': '۱۶۶ روز مانده',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'زمان باقی‌مانده',
      );
      expect(labelTooltip, findsOneWidget);

      final valueTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == '۱۶۶ روز مانده',
      );
      expect(valueTooltip, findsOneWidget);

      final labelText = tester.widget<Text>(find.descendant(of: labelTooltip, matching: find.byType(Text)));
      expect(labelText.softWrap, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Request attachments hint wraps to two lines with Tooltip at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = RequestFormController(
        fields: const [],
        limits: const RequestAttachmentLimits(
          maxFiles: 5,
          maxMb: 10,
          maxTotalMb: 30,
          extensions: ['jpg', 'jpeg', 'png', 'pdf', 'xls', 'xlsx', 'doc', 'docx'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: RequestAttachmentsPicker(
                controller: controller,
                enabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hintTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message?.startsWith('فرمت‌های مجاز:') ?? false),
      );
      expect(hintTooltip, findsOneWidget);

      final hintText = tester.widget<Text>(find.descendant(of: hintTooltip, matching: find.byType(Text)));
      expect(hintText.softWrap, isTrue);
      expect(hintText.maxLines, 2);
      expect(hintText.overflow, TextOverflow.ellipsis);

      expect(tester.takeException(), isNull);
    });

    testWidgets('WorkflowInstanceDetailPage overview card uses Tooltip for reference document and LTR isolate for email at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const item = WorkflowInstanceSummary(
        id: 'WFI-001',
        subject: 'خرید لپ‌تاپ',
        status: 'Rejected',
        currentStageTitle: 'Approval',
        currentAssignees: ['sales-manager@asoud-demo.local'],
        referenceDoctype: 'ASOUD Workflow Request',
        referenceName: 'REQ-00021',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: WorkflowInstanceOverviewCard(item: item),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final refDocTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'سند مرتبط',
      );
      expect(refDocTooltip, findsOneWidget);

      final assigneeWithIsolate = find.textContaining('${String.fromCharCode(0x2066)}sales-manager@asoud-demo.local${String.fromCharCode(0x2069)}');
      expect(assigneeWithIsolate, findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Workflow tasks page instance card formats assignee email with LTR isolate at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const item = WorkflowInstanceSummary(
        id: 'WFI-001',
        subject: 'درخواست مرخصی',
        status: 'Running',
        currentStageTitle: 'تأیید مدیر مستقیم',
        currentAssignees: ['sales-manager@asoud-demo.local'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: WorkflowInstanceSummaryCard(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final assigneeWithIsolate = find.textContaining('${String.fromCharCode(0x2066)}sales-manager@asoud-demo.local${String.fromCharCode(0x2069)}');
      expect(assigneeWithIsolate, findsOneWidget);

      final tooltipFinder = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message?.contains('sales-manager@asoud-demo.local') ?? false),
      );
      expect(tooltipFinder, findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
