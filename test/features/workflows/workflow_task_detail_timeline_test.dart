import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_instance_detail_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements WorkflowTaskRepository {
  _Repo({required this.detail, this.instance});
  final WorkflowTaskDetail detail;
  final WorkflowInstanceDetail? instance;

  @override
  bool get isOfflinePreview => false;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      [detail.task];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      this.instance!;

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) async =>
      '';

  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) async {}
}

final _activities = <WorkflowTaskActivity>[
  WorkflowTaskActivity(
    actor: 'علی رضایی',
    action: 'Approve',
    createdOn: DateTime.utc(2026, 10, 1, 8, 30),
  ),
  WorkflowTaskActivity(
      actor: 'سارا محمدی', action: 'Reject', comment: 'بودجه کافی نیست'),
  WorkflowTaskActivity(actor: 'رضا کریمی', action: 'Return'),
];

WorkflowTaskDetail _detail() => WorkflowTaskDetail(
      task: const WorkflowTask(
        id: 'WFT-2026-00042',
        instance: 'WFI-2026-00042',
        stage: 'STAGE-APPROVAL',
        title: 'تأیید درخواست خرید لپ‌تاپ',
        status: 'Open',
      ),
      stageType: 'Approval',
      activities: _activities,
    );

Widget _wrap(Widget child, WorkflowTaskRepository repository) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, c) =>
            Directionality(textDirection: TextDirection.rtl, child: c!),
        home: child,
      ),
    );

/// The outcome colour lives on the avatar behind the (white) status icon.
Color? _outcomeColor(WidgetTester tester, IconData icon) {
  final avatar = tester.widget<CircleAvatar>(find
      .ancestor(of: find.byIcon(icon), matching: find.byType(CircleAvatar))
      .first);
  return avatar.backgroundColor;
}

void main() {
  test('نتیجهٔ اقدام‌ها به رنگ/آیکون درست نگاشت می‌شود', () {
    expect(workflowActivityOutcome('Approve'),
        WorkflowActivityOutcome.approved);
    expect(workflowActivityOutcome('Complete'),
        WorkflowActivityOutcome.approved);
    expect(workflowActivityOutcome('Condition True'),
        WorkflowActivityOutcome.approved);
    expect(workflowActivityOutcome('Reject'),
        WorkflowActivityOutcome.rejected);
    expect(workflowActivityOutcome('Condition False'),
        WorkflowActivityOutcome.rejected);
    expect(workflowActivityOutcome('Return'),
        WorkflowActivityOutcome.returned);
    expect(workflowActivityOutcome('summon'),
        WorkflowActivityOutcome.neutral);
  });

  testWidgets('خط زمان کارتابل برچسب فارسی و رنگ نتیجه را نشان می‌دهد',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(
        const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
        _Repo(detail: _detail())));
    await tester.pumpAndSettle();

    // هیچ متن انگلیسی سرور نباید به کاربر برسد
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Return'), findsNothing);

    expect(find.text('تأیید شد'), findsOneWidget);
    expect(find.text('رد شد'), findsOneWidget);
    expect(find.text('برای اصلاح بازگردانده شد'), findsOneWidget);
    expect(find.text('در انتظار اقدام شما'), findsOneWidget);

    expect(_outcomeColor(tester, Icons.check_circle_rounded),
        AsoudColors.success);
    expect(_outcomeColor(tester, Icons.cancel_rounded), AsoudColors.danger);
    expect(_outcomeColor(tester, Icons.undo_rounded), AsoudColors.warning);
    expect(_outcomeColor(tester, Icons.schedule_rounded), AsoudColors.muted);

    expect(tester.takeException(), isNull);
  });

  testWidgets('صفحهٔ پیگیری هم از همان خط زمان رنگی استفاده می‌کند',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo(
      detail: _detail(),
      instance: WorkflowInstanceDetail(
        summary: const WorkflowInstanceSummary(
          id: 'WFI-2026-00042',
          subject: 'خرید لپ‌تاپ',
          status: 'Rejected',
        ),
        activities: _activities,
      ),
    );
    await tester.pumpWidget(
        _wrap(const WorkflowInstanceDetailPage(instance: 'WFI-2026-00042'), repo));
    await tester.pumpAndSettle();

    expect(find.text('رد شد'), findsOneWidget);
    expect(_outcomeColor(tester, Icons.cancel_rounded), AsoudColors.danger);
    expect(
        _outcomeColor(tester, Icons.check_circle_rounded), AsoudColors.success);
    expect(tester.takeException(), isNull);
  });
}
