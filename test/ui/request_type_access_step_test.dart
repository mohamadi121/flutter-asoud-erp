import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_type_builder_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _UserTypeRepository extends Fake implements WorkflowRepository {
  _UserTypeRepository();

  final List<String> savedInitiatorRoles = [];
  static const roles = ['کارمند', 'مدیر'];

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
        stages: const [
          WorkflowStage(
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
              config: {'form_fields': <Map<String, dynamic>>[]}),
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
  }) async =>
      _design;

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      WorkflowFormOptions(companies: const [], modules: const [], roles: roles);

  @override
  Future<WorkflowStage> saveStartSettings({
    required String definition,
    required String triggerType,
    required List<String> initiatorRoles,
    required String subjectSource,
    required String passMode,
  }) async {
    savedInitiatorRoles
      ..clear()
      ..addAll(initiatorRoles);
    return _design.stages.first;
  }
}

Future<void> _pump(WidgetTester tester, _UserTypeRepository repository) async {
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

void main() {
  testWidgets('نوع کاربری گام «دسترسی» را نشان می‌دهد و نقش را ذخیره می‌کند',
      (tester) async {
    final repository = _UserTypeRepository();
    await _pump(tester, repository);

    await _continue(tester); // 0 -> 1
    await _continue(tester); // 1 -> 2
    expect(find.text('پیش‌نمایش فرم درخواست'), findsOneWidget);

    await _continue(tester); // 2 -> 3 (access)
    expect(find.text('دسترسی ثبت درخواست'), findsOneWidget);
    expect(find.text('کارمند'), findsOneWidget);
    expect(find.text('مدیر'), findsOneWidget);
    // The last step offers the final save, not «ادامه».
    expect(find.text('ذخیره و پایان'), findsOneWidget);

    // Without a role the save is refused with a Persian message.
    await tester.tap(find.text('ذخیره و پایان'));
    await tester.pumpAndSettle();
    expect(find.text('حداقل یک نقش مجاز انتخاب کنید.'), findsOneWidget);
    expect(repository.savedInitiatorRoles, isEmpty);

    // Select a role, then save.
    await tester.tap(find.text('کارمند'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره و پایان'));
    await tester.pumpAndSettle();
    expect(repository.savedInitiatorRoles, ['کارمند']);
    expect(find.byType(RequestTypeBuilderPage), findsNothing);
  });

  testWidgets('روی عرض ۳۲۰ گام دسترسی بدون سرریز جا می‌شود', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _UserTypeRepository();
    await _pump(tester, repository);

    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    expect(find.text('دسترسی ثبت درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
