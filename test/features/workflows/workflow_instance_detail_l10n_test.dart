import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_instance_detail_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_activity_timeline.dart';

void main() {
  group('T1: Workflow stage and timeline localization', () {
    test(
        'persianWorkflowStageTitle maps standard stages and full-sentence variants',
        () {
      expect(persianWorkflowStageTitle('Approval'), 'تأیید');
      expect(persianWorkflowStageTitle('End'), 'پایان');
      expect(persianWorkflowStageTitle('User Task'), 'وظیفه کاربر');
      expect(persianWorkflowStageTitle('Start'), 'شروع');
      expect(persianWorkflowStageTitle('System Action'), 'اقدام خودکار');
      expect(persianWorkflowStageTitle('Condition'), 'شرط');
      expect(persianWorkflowStageTitle('Wait'), 'انتظار');

      // Sentence variants
      expect(persianWorkflowStageTitle('Stage: Approval'), 'تأیید');
      expect(persianWorkflowStageTitle('Approval Stage'), 'تأیید');
      expect(persianWorkflowStageTitle('Stage: End'), 'پایان');
      expect(persianWorkflowStageTitle('Workflow Stage: Start'), 'شروع');
      expect(persianWorkflowStageTitle('End Process'), 'پایان');
    });

    testWidgets(
        'WorkflowInstanceOverviewCard translates Approval and End to Persian',
        (tester) async {
      const itemApproval = WorkflowInstanceSummary(
        id: 'WFI-001',
        subject: 'خرید لپ‌تاپ',
        status: 'Rejected',
        currentStageTitle: 'Approval',
        currentAssignees: [],
        referenceDoctype: 'ASOUD Workflow Request',
        referenceName: 'REQ-00021',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: WorkflowInstanceOverviewCard(item: itemApproval),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأیید'), findsOneWidget);
      expect(find.text('Approval'), findsNothing);

      const itemEnd = WorkflowInstanceSummary(
        id: 'WFI-002',
        subject: 'مرخصی سه‌روزه',
        status: 'Completed',
        currentStageTitle: 'End',
        currentAssignees: [],
        referenceDoctype: 'ASOUD Workflow Request',
        referenceName: 'REQ-00013',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: WorkflowInstanceOverviewCard(item: itemEnd),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('پایان'), findsOneWidget);
      expect(find.text('End'), findsNothing);
    });

    testWidgets(
        'WorkflowActivityTimeline translates English stage actions in timeline',
        (tester) async {
      final activities = [
        WorkflowTaskActivity(
          actor: 'sales-manager@asoud-demo.local',
          action: 'Approval',
          comment: 'بررسی شد',
          createdOn: DateTime(2026, 10, 11),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: WorkflowActivityTimeline(activities: activities),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأیید'), findsOneWidget);
      expect(find.text('Approval'), findsNothing);
    });
  });
}
