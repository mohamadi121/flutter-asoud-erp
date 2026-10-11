import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves one task detail with the shape the server returns for a cartable
/// task: referenced document values (including the raw identifiers the page
/// must hide) plus the requester from a previous stage's response.
class _DetailRepository implements WorkflowTaskRepository {
  _DetailRepository(this.detail);
  final WorkflowTaskDetail detail;

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
      throw UnimplementedError();

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

const _fingerprint = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

WorkflowTaskDetail _detail() => WorkflowTaskDetail(
      task: const WorkflowTask(
        id: 'WFT-2026-00042',
        instance: 'WFI-2026-00042',
        stage: 'STAGE-APPROVAL',
        title: 'تأیید درخواست خرید لپ‌تاپ',
        status: 'Open',
      ),
      stageType: 'Approval',
      documentValues: const [
        WorkflowTaskDataValue(
            key: 'request_type', label: 'Request Type', value: 'درخواست خرید'),
        WorkflowTaskDataValue(
            key: 'priority', label: 'Priority', value: 'Urgent'),
        WorkflowTaskDataValue(
            key: 'requester', label: 'Requester', value: 'سارا محمدی'),
        WorkflowTaskDataValue(
            key: 'request_fingerprint',
            label: 'request_fingerprint',
            value: _fingerprint),
        WorkflowTaskDataValue(
            key: 'subject', label: 'Subject', value: 'خرید لپ‌تاپ برای فروش'),
      ],
      previousData: const [
        WorkflowTaskDataSection(
          title: 'اطلاعات درخواست ثبت‌شده',
          values: [
            WorkflowTaskDataValue(
                key: 'amount', label: 'مبلغ برآوردی', value: 145000000),
          ],
        ),
      ],
    );

Widget _app(WorkflowTaskRepository repository) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
      ),
    );

Future<void> _pumpAt(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(_DetailRepository(_detail())));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in const [320.0, 390.0]) {
    testWidgets('خلاصه کارتابل حداکثر پنج ردیف و جزئیات فنی بسته است ($width)',
        (tester) async {
      await _pumpAt(tester, width);

      expect(find.text('نوع درخواست'), findsOneWidget);
      expect(find.text('درخواست خرید'), findsOneWidget);
      expect(find.text('درخواست‌کننده'), findsOneWidget);
      expect(find.text('سارا محمدی'), findsOneWidget);
      expect(find.text('موضوع'), findsOneWidget);
      expect(find.text('خرید لپ‌تاپ برای فروش'), findsOneWidget);
      expect(find.text('اولویت / وضعیت'), findsOneWidget);
      expect(find.textContaining('فوری'), findsOneWidget);

      // فاش‌نشدن شناسه فنی تا پیش از باز کردن بخش جزئیات فنی
      expect(find.text('جزئیات فنی'), findsOneWidget);
      expect(find.text(_fingerprint), findsNothing);

      await tester.ensureVisible(find.text('جزئیات فنی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جزئیات فنی'));
      await tester.pumpAndSettle();
      expect(find.text(_fingerprint), findsOneWidget);
      expect(find.text('request_fingerprint'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }
}
