import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

WorkflowStage _stage(String id, WorkflowStageType type, String title, int seq,
        [Map<String, dynamic> config = const {}]) =>
    WorkflowStage(
        id: id,
        key: id,
        type: type,
        title: title,
        sequence: seq,
        configurationComplete: true,
        config: config);

final _design = WorkflowDesign(
  workflow: const WorkflowDefinition(
      id: 'WF-1',
      code: 'purchase',
      title: 'درخواست خرید',
      targetDoctype: 'ASOUD Workflow Request',
      status: WorkflowDefinitionStatus.active,
      isLocked: false,
      version: 1,
      stepsCount: 6,
      modified: null,
      company: 'تابان'),
  stages: [
    _stage('S0', WorkflowStageType.start, 'شروع', 1),
    _stage('S1', WorkflowStageType.userTask, 'ثبت درخواست', 2),
    _stage('S2', WorkflowStageType.approval, 'تأیید مدیر مستقیم', 3,
        {'assignment_type': 'Direct Manager', 'approval_mode': 'Any'}),
    _stage('S3', WorkflowStageType.systemAction, 'ثبت سند', 4,
        {'action_type': 'Change Status', 'request_status': 'در حال ثبت'}),
    _stage('S4', WorkflowStageType.end, 'پایان فرایند', 5),
    _stage('S5', WorkflowStageType.end, 'رد درخواست', 6),
  ],
  transitions: const [
    WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S1'),
    WorkflowTransition(id: 'T2', fromStage: 'S1', toStage: 'S2'),
    WorkflowTransition(id: 'T3', fromStage: 'S2', toStage: 'S3'),
    WorkflowTransition(id: 'T4', fromStage: 'S3', toStage: 'S4'),
  ],
);

const _options = WorkflowFormOptions(
  companies: ['تابان'],
  modules: [],
  roles: ['Accounts Manager', 'Purchase Manager'],
  departments: [
    WorkflowTargetOption(id: 'All', label: 'همه واحدها', isGroup: true),
    WorkflowTargetOption(
        id: 'FIN', label: 'مالی و حسابداری', parent: 'All', isGroup: true),
    WorkflowTargetOption(id: 'TRE', label: 'واحد خزانه', parent: 'FIN'),
    WorkflowTargetOption(id: 'BUY', label: 'بازرگانی', parent: 'All'),
  ],
  employees: [
    WorkflowTargetOption(
        id: 'EMP-1',
        label: 'علی محمدی',
        department: 'BUY',
        designation: 'مدیر بازرگانی'),
    WorkflowTargetOption(
        id: 'EMP-2',
        label: 'سارا احمدی',
        department: 'BUY',
        designation: 'حسابدار'),
  ],
);

class _Workflows extends Fake implements WorkflowRepository {
  _Workflows([this.design]);
  final WorkflowDesign? design;
  final saved = <Map<String, dynamic>>[];
  @override
  Future<WorkflowDesign> getDesign(String definition) async => design ?? _design;
  @override
  Future<WorkflowFormOptions> getFormOptions() async => _options;
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved.add(config);
    return design ?? _design;
  }
}

class _Automation extends Fake implements WorkflowAutomationRepository {
  @override
  final bool isLocal = false;
  final routes = <Map<String, String>>[];
  @override
  Future<void> saveStageRoutes(
      {required String definition,
      required String stage,
      required Map<String, String> routes}) async {
    this.routes.add(routes);
  }
}

Future<(_Workflows, _Automation)> _open(
    WidgetTester tester, String stageId, {WorkflowDesign? designOverride}) async {
  final design = designOverride ?? _design;
  final workflows = _Workflows(design);
  final automation = _Automation();
  final cubit =
      WorkflowDesignerCubit(repository: workflows, definition: 'WF-1');
  await cubit.load();
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: BlocProvider.value(
      value: cubit,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: StageSettingsPage(
                              stage: design.stages
                                  .firstWhere((stage) => stage.id == stageId),
                              design: design,
                              options: _options,
                              automation: automation)))),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
  return (workflows, automation);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 20; attempt++) {
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) break;
    await tester.drag(lists.last, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

void main() {
  // --- (a) decisions are three checkboxes; a disabled decision makes no route ---

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('approval shows the three decision checkboxes at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, 'S2');
      await _scrollToFinder(tester, find.text('تصمیم‌های قابل انجام'));
      expect(find.text('امکان تأیید'), findsOneWidget);
      expect(find.text('امکان رد'), findsOneWidget);
      expect(find.text('امکان بازگشت برای اصلاح'), findsOneWidget);
      // Approve is always on and cannot be toggled off.
      final approve = tester.widget<CheckboxListTile>(
          find.ancestor(of: find.text('امکان تأیید'),
              matching: find.byType(CheckboxListTile)));
      expect(approve.value, isTrue);
      expect(approve.onChanged, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disabling a decision without a route saves no route for it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, 'S2');
    await _tap(tester, find.text('امکان رد'));
    await _tap(tester, find.text('امکان بازگشت برای اصلاح'));
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['allow_reject'], isFalse);
    expect(config['allow_return'], isFalse);
    // No Reject/Return destination was ever chosen, so no route is sent.
    expect(automation.routes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling a decision that has a route removes it on confirm',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final design = WorkflowDesign(workflow: _design.workflow,
        stages: _design.stages,
        transitions: [..._design.transitions, const WorkflowTransition(id: 'R1',
            fromStage: 'S2', toStage: 'S5', label: 'رد', condition: {'action': 'Reject'})]);
    final (workflows, automation) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('امکان رد'));
    expect(find.text('غیرفعال‌کردن تصمیم'), findsOneWidget);
    await _tap(tester, find.text('تأیید غیرفعال‌سازی'));
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['allow_reject'], isFalse);
    expect(automation.routes.single, {'Reject': ''});
    expect(tester.takeException(), isNull);
  });

  // --- (b) approvers use the same role / org-unit picker; several can be added ---

  testWidgets('approval owner uses the same role picker as a user action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, 'S2');
    await _tap(tester, find.text('نقش'));
    await _tap(tester, find.text('مدیر مستقیم'));
    // The shared role chooser opens with the same title as the user action.
    expect(find.text('انتخاب نقش مسئول'), findsOneWidget);
    await _tap(tester, find.text('مدیر مالی'));
    await _tap(tester, find.text('تأیید انتخاب'));
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['assignment_type'], 'Role');
    expect(config['approver_roles'], ['Accounts Manager']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('several approvers can be added from the org-unit picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, 'S2');
    await _tap(tester, find.text('واحد سازمانی'));
    await _tap(tester, find.text('انتخاب واحد'));
    await _tap(tester, find.text('بازرگانی'));
    await _tap(tester, find.text('تأیید انتخاب'));
    await _tap(tester, find.text('یک فرد مشخص'));
    await _tap(tester, find.text('انتخاب فرد'));
    await _tap(tester, find.text('علی محمدی'));
    await _tap(tester, find.text('سارا احمدی'));
    await _tap(tester, find.text('تأیید انتخاب'));
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['assignment_type'], 'Employee');
    expect(config['approver_employees'], ['EMP-1', 'EMP-2']);
    expect(tester.takeException(), isNull);
  });

  // --- (c) one approver decides alone; several need ALL (approval_mode) ---

  testWidgets('a new pending approval defaults to All so every approver is needed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = WorkflowStage(id: 'S2', key: 'S2', type: WorkflowStageType.approval,
        title: 'تأیید مدیر مستقیم', sequence: 3, configurationComplete: false);
    final design = WorkflowDesign(workflow: _design.workflow,
        stages: [for (final stage in _design.stages) stage.id == 'S2' ? pending : stage],
        transitions: _design.transitions);
    final (workflows, _) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['approval_mode'], 'All');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a legacy Any approval keeps Any and is not converted',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, 'S2');
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['approval_mode'], 'Any');
    expect(tester.takeException(), isNull);
  });
}
