import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements WorkflowTaskRepository, WorkflowInstanceSummariesRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async => const [
        WorkflowTask(
          id: 'WFT-1',
          instance: 'WFI-123',
          stage: 'Approval',
          title: 'تأیید',
          status: 'Open',
        ),
      ];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [];

  @override
  Future<List<WorkflowInstanceSummary>> getInstanceSummaries(
      List<String> names) async => const [
        WorkflowInstanceSummary(
          id: 'WFI-123',
          subject: 'خرید لپ‌تاپ',
          status: 'Running',
        ),
      ];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<WorkflowTaskDetail> getTask(String task) async =>
      throw UnimplementedError();

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) async =>
      'local://$filename';

  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) async {}
}

Widget _app(WorkflowTaskRepository repo) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const WorkflowTasksPage(),
      ),
    );

void main() {
  testWidgets('task card shows the instance subject and keeps the technical id',
      (tester) async {
    for (final width in [320.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(_FakeRepo()));
      await tester.pumpAndSettle();

      // The instance subject is the visible text on the card.
      expect(find.text('خرید لپ‌تاپ'), findsOneWidget);
      // The technical id is still available (tooltip), not removed.
      expect(
        find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == 'WFI-123'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
