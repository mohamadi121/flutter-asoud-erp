import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_status.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_instance_detail_page.dart';

void main() {
  group('Designed Stop outcome (status: Failed, end_outcome: Stopped)', () {
    test('RequestSummary and requestStatus with end_outcome Stopped give متوقف شد and muted color even if status_label is present', () {
      final summaryMap = {
        'name': 'REQ-001',
        'status': 'Failed',
        'status_key': 'failed',
        'status_label': 'نیازمند بررسی',
        'end_outcome': 'Stopped',
      };
      final summary = RequestSummary.fromMap(summaryMap);
      expect(summary.statusLabel, 'متوقف شد');

      final (label, color) = requestStatus(summaryMap);
      expect(label, 'متوقف شد');
      expect(color, AsoudColors.muted);
    });

    test('RequestSummary and requestStatus without end_outcome give نیازمند بررسی and danger color', () {
      final summaryMap = {
        'name': 'REQ-002',
        'status': 'Failed',
        'status_key': 'failed',
        'status_label': 'نیازمند بررسی',
      };
      final summary = RequestSummary.fromMap(summaryMap);
      expect(summary.statusLabel, 'نیازمند بررسی');

      final (label, color) = requestStatus(summaryMap);
      expect(label, 'نیازمند بررسی');
      expect(color, AsoudColors.danger);
    });

    test('RequestDetail with end_outcome Stopped gives متوقف شد even if status_label is present', () {
      final detailMap = {
        'name': 'REQ-003',
        'status': 'Failed',
        'status_key': 'failed',
        'status_label': 'نیازمند بررسی',
        'end_outcome': 'Stopped',
      };
      final detail = RequestDetail.fromMap(detailMap);
      expect(detail.statusLabel, 'متوقف شد');
    });

    testWidgets('Instance detail page shows متوقف شد for Stopped outcome and ناموفق for regular Failed at 320 and 390 px width', (tester) async {
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const summaryStopped = WorkflowInstanceSummary(
          id: 'WFI-STOPPED',
          subject: 'درخواست متوقف‌شده',
          status: 'Failed',
          endOutcome: 'Stopped',
          currentStageTitle: 'End',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: WorkflowInstanceOverviewCard(item: summaryStopped),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('متوقف شد'), findsOneWidget);
        expect(find.text('ناموفق'), findsNothing);

        const summaryFailed = WorkflowInstanceSummary(
          id: 'WFI-FAILED',
          subject: 'درخواست ناموفق',
          status: 'Failed',
          endOutcome: '',
          currentStageTitle: 'End',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: WorkflowInstanceOverviewCard(item: summaryFailed),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ناموفق'), findsOneWidget);
        expect(find.text('متوقف شد'), findsNothing);
      }
    });
  });
}
