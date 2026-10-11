import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_type_builder_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _UserMadeTypeRepository extends Fake implements WorkflowRepository {
  _UserMadeTypeRepository({
    required this.formFields,
    this.saveError,
  });

  final List<Map<String, dynamic>> formFields;
  final Object? saveError;
  int saveCalls = 0;

  final WorkflowDefinition definition = WorkflowDefinition(
    id: 'WF-USER-1',
    code: 'USER_BUY',
    title: 'درخواست خرید کاربر',
    targetDoctype: 'ASOUD Workflow Request',
    status: WorkflowDefinitionStatus.inactive,
    isLocked: false,
    version: 1,
    stepsCount: 2,
    modified: DateTime(2026, 10, 1),
    isSystemTemplate: false,
  );

  WorkflowDesign get _design => WorkflowDesign(
        workflow: definition,
        stages: [
          const WorkflowStage(
              id: 'STAGE-START',
              key: 'start',
              type: WorkflowStageType.start,
              title: 'شروع',
              sequence: 0,
              configurationComplete: true),
          WorkflowStage(
              id: 'STAGE-FORM',
              key: 'form',
              type: WorkflowStageType.userTask,
              title: 'تکمیل فرم درخواست',
              sequence: 1,
              configurationComplete: true,
              config: {'form_fields': formFields}),
        ],
        transitions: const [
          WorkflowTransition(
              id: 'T1', fromStage: 'STAGE-START', toStage: 'STAGE-FORM'),
        ],
      );

  @override
  Future<WorkflowDesign> getDesign(String definition) async => _design;

  @override
  Future<WorkflowDefinition> saveRequestTypeInfo({
    required String definition,
    required RequestTypeInfo info,
  }) async =>
      this.definition;

  @override
  Future<WorkflowDesign> saveStageSettings({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
  }) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    return _design;
  }
}

Future<void> _pump(WidgetTester tester, _UserMadeTypeRepository repository) async {
  await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
    value: repository,
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RequestTypeBuilderPage(existing: repository.definition),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('ادامه'));
  await tester.pumpAndSettle();
}

const _twoFields = [
  {
    'key': 'subject',
    'label': 'موضوع خرید',
    'type': 'Short Text',
    'required': true,
  },
  {'key': 'details', 'label': 'جزئیات', 'type': 'Long Text'},
];

void main() {
  testWidgets(
      'user-made type with form fields advances from فرم درخواست to preview',
      (tester) async {
    final repository = _UserMadeTypeRepository(formFields: _twoFields);
    await _pump(tester, repository);

    await _continue(tester); // step 0 -> step 1
    expect(find.text('فرم درخواست'), findsOneWidget);

    await _continue(tester); // step 1 -> step 2
    expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);
    expect(repository.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'user-made type with no custom fields still advances to preview',
      (tester) async {
    final repository = _UserMadeTypeRepository(formFields: const []);
    await _pump(tester, repository);

    await _continue(tester);
    await _continue(tester);

    expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);
    expect(repository.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'server refusal on فرم درخواست shows the Persian reason and does not dead-end silently',
      (tester) async {
    final repository = _UserMadeTypeRepository(
      formFields: _twoFields,
      saveError: const ApiException(
          kind: ApiFailureKind.forbidden,
          message: 'PermissionError: not allowed',
          statusCode: 403),
    );
    await _pump(tester, repository);

    await _continue(tester);
    await _continue(tester);

    expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
    expect(find.text('پیش‌نمایش فرم درخواست'), findsNothing);
    expect(repository.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'validation refusal (417) on فرم درخواست shows a Persian reason',
      (tester) async {
    final repository = _UserMadeTypeRepository(
      formFields: const [],
      saveError: const ApiException(
          kind: ApiFailureKind.validation,
          message: 'Workflow stages and transitions are not complete',
          statusCode: 417),
    );
    await _pump(tester, repository);

    await _continue(tester);
    await _continue(tester);

    expect(find.text('اطلاعات واردشده را بررسی کنید.'), findsOneWidget);
    expect(find.text('پیش‌نمایش فرم درخواست'), findsNothing);
    expect(repository.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
