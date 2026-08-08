import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApprovalRepository implements WorkflowTaskRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async =>
      const WorkflowTaskDetail(
        task: WorkflowTask(
          id: 'TASK-1',
          instance: 'INSTANCE-1',
          stage: 'APPROVAL-1',
          title: 'تأیید درخواست خرید',
          status: 'Open',
        ),
        stageType: 'Approval',
        allowReject: true,
        allowReturn: true,
        commentRequired: true,
        previousData: [
          WorkflowTaskDataSection(
            title: 'ثبت درخواست',
            values: [
              WorkflowTaskDataValue(
                  key: 'title', label: 'عنوان درخواست', value: 'خرید کاغذ'),
            ],
          ),
        ],
      );

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      const [];
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

void main() {
  testWidgets('صفحه تأیید اطلاعات قبلی و فرم علت بازگشت را نمایش می‌دهد',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepositoryProvider<WorkflowTaskRepository>.value(
        value: _ApprovalRepository(),
        child: MaterialApp(
          theme: AsoudTheme.light,
          locale: const Locale('fa'),
          home: const WorkflowTaskDetailPage(task: 'TASK-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مرحله تأیید'), findsOneWidget);
    expect(find.text('خرید کاغذ'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بازگشت برای اصلاح'));
    await tester.pumpAndSettle();
    expect(find.text('مواردی که باید اصلاح شوند را بنویسید.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
