import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/receipt_confirmation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tasks implements WorkflowTaskRepository {
  _Tasks(this.detail);
  final WorkflowTaskDetail detail;
  var completeCalls = 0;

  @override
  bool get isOfflinePreview => false;
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async => [];
  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances(
          {String? status}) async =>
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
      Map<String, dynamic> response = const {}}) async {
    completeCalls++;
  }
}

class _Receipts implements ReceiptConfirmationRepository {
  final calls = <String>[];
  Object? failure;

  @override
  Future<void> confirm(String task) async {
    calls.add('confirm:$task');
    if (failure != null) throw failure!;
  }

  @override
  Future<void> reject(String task, String reason) async {
    calls.add('reject:$task:$reason');
    if (failure != null) throw failure!;
  }
}

// The shape get_workflow_task returns for a receipt task (docs/api/form-execution.md).
WorkflowTaskDetail _detail({String status = 'Open'}) => WorkflowTaskDetail(
      task: WorkflowTask(
        id: 'WFT-9',
        instance: 'WFI-9',
        stage: 'S-END',
        title: 'تأیید دریافت تجهیز: لپ‌تاپ اداری',
        status: status,
        followup: 'confirm_receipt',
      ),
      stageType: 'User Task',
      activityType: 'ConfirmReceipt',
      allowReject: true,
      referenceDoctype: 'Asset Movement',
      referenceName: 'ACC-ASM-00009',
      documentValues: const [
        WorkflowTaskDataValue(key: 'asset', label: 'تجهیز', value: 'لپ‌تاپ اداری'),
        WorkflowTaskDataValue(
            key: 'transaction_date', label: 'تاریخ تحویل', value: '2026-10-23'),
        WorkflowTaskDataValue(
            key: 'target_location', label: 'مکان تحویل', value: 'انبار مرکزی'),
        WorkflowTaskDataValue(
            key: 'movement_status', label: 'وضعیت', value: 'پیش‌نویس'),
      ],
    );

Widget _app(_Tasks tasks, _Receipts receipts) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WorkflowTaskRepository>.value(value: tasks),
        RepositoryProvider<ReceiptConfirmationRepository>.value(value: receipts),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                        builder: (_) =>
                            const WorkflowTaskDetailPage(task: 'WFT-9'))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<(_Tasks, _Receipts)> _open(WidgetTester tester, double width,
    {String status = 'Open'}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final tasks = _Tasks(_detail(status: status));
  final receipts = _Receipts();
  await tester.pumpWidget(_app(tasks, receipts));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (tasks, receipts);
}

Finder _confirm() => find.widgetWithText(FilledButton, 'تأیید دریافت');
Finder _reject() => find.widgetWithText(FilledButton, 'عدم دریافت با ذکر علت');

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('receipt task shows the asset and both choices at $width',
        (tester) async {
      await _open(tester, width);
      expect(find.text('لپ‌تاپ اداری'), findsWidgets);
      expect(find.text('انبار مرکزی'), findsOneWidget);
      expect(_confirm(), findsOneWidget);
      expect(_reject(), findsOneWidget);
      // None of the generic decision controls are offered for this task.
      expect(find.widgetWithText(FilledButton, 'رد'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'بازگشت'), findsNothing);
      expect(find.text('ذخیره پیش‌نویس'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirming calls the receipt endpoint only and closes the page',
      (tester) async {
    final (tasks, receipts) = await _open(tester, 390);
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(receipts.calls, ['confirm:WFT-9']);
    expect(tasks.completeCalls, 0);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('not receiving needs a reason and sends it', (tester) async {
    final (_, receipts) = await _open(tester, 320);
    expect(tester.widget<FilledButton>(_reject()).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(_reject()).onPressed, isNull);
    await tester.enterText(find.byType(TextField), ' تجهیز نرسید ');
    await tester.pump();
    await tester.tap(_reject());
    await tester.pumpAndSettle();
    expect(receipts.calls, ['reject:WFT-9:تجهیز نرسید']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a server refusal shows its Persian sentence and stays open',
      (tester) async {
    final (_, receipts) = await _open(tester, 390);
    receipts.failure = const ApiException(
        kind: ApiFailureKind.validation,
        statusCode: 417,
        message:
            'جابه‌جایی این تجهیز لغو شده است و دریافت آن قابل تأیید نیست.');
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(
        find.text('جابه‌جایی این تجهیز لغو شده است و دریافت آن قابل تأیید نیست.'),
        findsOneWidget);
    expect(find.text('open'), findsNothing);
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNotNull);
  });

  testWidgets('a closed receipt task offers no action', (tester) async {
    await _open(tester, 390, status: 'Completed');
    expect(_confirm(), findsNothing);
    expect(_reject(), findsNothing);
    expect(find.text('لپ‌تاپ اداری'), findsWidgets);
  });
}
