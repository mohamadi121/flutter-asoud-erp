import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_supplementary_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
}

class _SupplementaryCall {
  const _SupplementaryCall(
      this.action, this.comment, this.response, this.supplementaryValues);
  final String action;
  final String? comment;
  final Map<String, dynamic> response;
  final Map<String, dynamic> supplementaryValues;
}

/// A task repository that can send the supplementary form (contract C6). It
/// records which path the decision took so a test can prove the values
/// travelled as `supplementary_values` and not inside the decision response.
class _FakeTaskRepository
    implements WorkflowTaskRepository, WorkflowTaskSupplementaryRepository {
  _FakeTaskRepository(this.detail, {this.offline = false});
  final WorkflowTaskDetail detail;

  /// When true, models the offline preview: the supplementary path cannot be
  /// recorded locally and throws, exactly like `PreviewWorkflowTaskRepository`.
  final bool offline;
  final List<_SupplementaryCall> completeCalls = [];
  final List<String> plainCompleteActions = [];
  final List<Map<String, dynamic>> draftCalls = [];
  final List<Map<String, dynamic>> plainDraftCalls = [];
  Object? completeError;

  @override
  bool get isOfflinePreview => offline;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      [detail.task];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances(
          {String? status}) async =>
      const [];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async =>
      plainDraftCalls.add(values);

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
          Map<String, dynamic> response = const {}}) async =>
      plainCompleteActions.add(action);

  @override
  Future<void> completeTaskWithSupplementary(
      {required String task,
      required String action,
      String? comment,
      Map<String, dynamic> response = const {},
      required Map<String, dynamic> supplementaryValues}) async {
    if (offline) throw _offlineSupplementary();
    if (completeError != null) throw completeError!;
    completeCalls.add(
        _SupplementaryCall(action, comment, response, supplementaryValues));
  }

  @override
  Future<void> saveDraftWithSupplementary(
      String task, Map<String, dynamic> values,
      {required Map<String, dynamic> supplementaryValues}) async {
    if (offline) throw _offlineSupplementary();
    draftCalls.add(supplementaryValues);
  }

  /// The same reason the offline preview throws, so the test proves the
  /// Persian text survives `failureDetail`.
  ApiException _offlineSupplementary() => const ApiException(
        kind: ApiFailureKind.validation,
        message: 'ثبت فرم تکمیلی نیازمند ارتباط واقعی با سرور است.',
      );
}

/// An approval task whose stage is bound to a real ASOUD Form (contract C6).
WorkflowTaskDetail _detail(
        {String status = 'Open',
        Map<String, dynamic> savedValues = const {}}) =>
    WorkflowTaskDetail(
      task: WorkflowTask(
          id: 'WFT-1',
          instance: 'WFI-1',
          stage: 'STAGE-APPROVAL',
          title: 'تأیید درخواست',
          status: status),
      stageType: 'Approval',
      allowReject: true,
      allowReturn: true,
      supplementaryForm: {
        'form': 'ASOUD-Form-Stage-Checklist',
        'revision': 'REV-1',
        'title': 'چک‌لیست بررسی درخواست',
        'schema': {
          'kind': 'Stage',
          'sections': [
            {
              'id': 'main',
              'title': 'بررسی',
              'fields': [
                {'key': 'note', 'label': 'یادداشت', 'type': 'Text'},
              ]
            },
          ],
        },
        'values': savedValues,
      },
    );

/// The same approval task with no supplementary binding (legacy form_fields).
WorkflowTaskDetail _legacyDetail() => WorkflowTaskDetail(
      task: WorkflowTask(
          id: 'WFT-1',
          instance: 'WFI-1',
          stage: 'STAGE-APPROVAL',
          title: 'تأیید درخواست',
          status: 'Open'),
      stageType: 'Approval',
      allowReject: true,
      allowReturn: true,
    );

Widget _app(WorkflowTaskRepository repository) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FrappeApiClient>.value(value: _Client()),
          RepositoryProvider<WorkflowTaskRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AsoudTheme.light,
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const WorkflowTaskDetailPage(task: 'WFT-1'))),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));

Future<_FakeTaskRepository> _pump(
    WidgetTester tester, double width, WorkflowTaskDetail detail,
    {bool offline = false}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _FakeTaskRepository(detail, offline: offline);
  await tester.pumpWidget(_app(repository));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

Finder _button(String label) => find.widgetWithText(FilledButton, label);

/// The decision bar's reason field (hint «دلیل / توضیح»), distinct from the
/// supplementary form's own text inputs.
Finder _reasonField() => find.byWidgetPredicate((widget) =>
    widget is TextField && widget.decoration?.hintText == 'دلیل / توضیح');

void main() {
  testWidgets('کارت فرم تکمیلی با اتصال مرحله نمایش می‌شود', (tester) async {
    await _pump(tester, 390, _detail());
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    expect(find.text('اطلاعات تکمیلی؛ جدا از تصمیم تأیید یا رد ثبت می‌شود.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('بدون اتصال مرحله، کارت فرم تکمیلی پنهان است', (tester) async {
    await _pump(tester, 390, _legacyDetail());
    expect(find.text('چک‌لیست بررسی درخواست'), findsNothing);
    expect(find.text('اطلاعات تکمیلی؛ جدا از تصمیم تأیید یا رد ثبت می‌شود.'),
        findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('مقادیر واردشده با تأیید در supplementary_values ارسال می‌شوند',
      (tester) async {
    final repository = await _pump(tester, 390, _detail());
    await tester.enterText(find.byType(TextFormField), 'بررسی شد');
    await tester.pump();
    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    expect(repository.completeCalls, hasLength(1));
    final call = repository.completeCalls.single;
    expect(call.action, 'Approve');
    expect(call.supplementaryValues, {'note': 'بررسی شد'});
    expect(repository.plainCompleteActions, isEmpty);
  });

  testWidgets('رد بدون ورودی فرم تکمیلی از مسیر عادی تصمیم می‌رود',
      (tester) async {
    final repository = await _pump(tester, 390, _detail());
    await tester.enterText(_reasonField(), 'دلیل رد');
    await tester.pump();
    await tester.tap(_button('رد'));
    await tester.pumpAndSettle();
    expect(repository.plainCompleteActions, ['Reject']);
    expect(repository.completeCalls, isEmpty);
  });

  testWidgets('خطای اعتبارسنجی سرور نمایش داده می‌شود و صفحه می‌ماند',
      (tester) async {
    final repository = await _pump(tester, 390, _detail());
    repository.completeError = const ApiException(
        kind: ApiFailureKind.validation, message: 'فیلد الزامی است.');
    await tester.enterText(find.byType(TextFormField), 'بررسی شد');
    await tester.pump();
    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    expect(find.text('فیلد الزامی است.'), findsOneWidget);
    expect(_button('تأیید'), findsOneWidget);
    expect(repository.completeCalls, isEmpty);
  });

  testWidgets('کار تمام‌شده مقادیر را فقط‌خواندانه نشان می‌دهد',
      (tester) async {
    await _pump(tester, 390,
        _detail(status: 'Completed', savedValues: {'note': 'بررسی شد'}));
    final view = tester.widget<FormFieldsView>(find.byType(FormFieldsView));
    expect(view.enabled, isFalse);
    expect(view.snapshot, isTrue);
    expect(view.values['note'], 'بررسی شد');
    expect(_button('تأیید'), findsNothing);
  });

  testWidgets('بدون اتصال فرم تکمیلی، مسیر قدیمی تصمیم استفاده می‌شود',
      (tester) async {
    final repository = await _pump(tester, 390, _legacyDetail());
    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    expect(repository.plainCompleteActions, ['Approve']);
    expect(repository.completeCalls, isEmpty);
  });

  testWidgets('مقادیر فرم تکمیلی با ذخیرهٔ پیش‌نویس ارسال می‌شوند',
      (tester) async {
    final repository = await _pump(tester, 390, _detail());
    await tester.enterText(find.byType(TextFormField), 'در حال بررسی');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'ذخیره پیش‌نویس'));
    await tester.pumpAndSettle();
    expect(repository.draftCalls, hasLength(1));
    expect(repository.draftCalls.single, {'note': 'در حال بررسی'});
  });

  testWidgets('پیش‌نمایش آفلاین: رد بدون ورودی فرم تکمیلی از مسیر عادی می‌رود',
      (tester) async {
    final repository = await _pump(tester, 390, _detail(), offline: true);
    await tester.enterText(_reasonField(), 'دلیل رد');
    await tester.pump();
    await tester.tap(_button('رد'));
    await tester.pumpAndSettle();
    // Nothing typed in the supplementary form, so the plain decision path is
    // used and succeeds even offline; the supplementary path is never called.
    expect(repository.plainCompleteActions, ['Reject']);
    expect(repository.completeCalls, isEmpty);
    expect(_button('تأیید'), findsNothing);
  });

  testWidgets(
      'پیش‌نمایش آفلاین: با ورودی فرم تکمیلی دلیل فارسی نمایش داده می‌شود',
      (tester) async {
    final repository = await _pump(tester, 390, _detail(), offline: true);
    await tester.enterText(find.byType(TextFormField), 'بررسی شد');
    await tester.pump();
    await tester.tap(_button('تأیید'));
    await tester.pumpAndSettle();
    // The offline preview cannot record the supplementary form; the exact
    // Persian reason (an ApiException) survives failureDetail and is shown.
    expect(find.text('ثبت فرم تکمیلی نیازمند ارتباط واقعی با سرور است.'),
        findsOneWidget);
    expect(_button('تأیید'), findsOneWidget);
    expect(repository.completeCalls, isEmpty);
  });

  testWidgets('روی عرض ۳۲۰ کارت فرم تکمیلی بدون سرریز نمایش می‌شود',
      (tester) async {
    await _pump(tester, 320, _detail());
    expect(find.text('چک‌لیست بررسی درخواست'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
