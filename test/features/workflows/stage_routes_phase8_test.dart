import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
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

/// Start -> ثبت درخواست -> تأیید مدیر -> ثبت سند -> پایان.
/// The approval (S2) has an Approve route to the user task S3 and no Reject.
final _design = WorkflowDesign(
  workflow: const WorkflowDefinition(
      id: 'WF-1',
      code: 'purchase',
      title: 'درخواست خرید',
      targetDoctype: 'ASOUD Workflow Request',
      status: WorkflowDefinitionStatus.active,
      isLocked: false,
      version: 1,
      stepsCount: 5,
      modified: null,
      company: 'تابان'),
  stages: [
    _stage('S0', WorkflowStageType.start, 'شروع', 1),
    _stage('S1', WorkflowStageType.userTask, 'ثبت درخواست', 2),
    _stage('S2', WorkflowStageType.approval, 'تأیید مدیر مستقیم', 3,
        {'assignment_type': 'Direct Manager', 'approval_mode': 'Any'}),
    _stage('S3', WorkflowStageType.userTask, 'ثبت سند', 4),
    _stage('S4', WorkflowStageType.end, 'پایان فرایند', 5),
  ],
  transitions: const [
    WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S1'),
    WorkflowTransition(id: 'T2', fromStage: 'S1', toStage: 'S2'),
    WorkflowTransition(id: 'T3', fromStage: 'S2', toStage: 'S3',
        label: 'تأیید', condition: {'action': 'Approve'}),
    WorkflowTransition(id: 'T4', fromStage: 'S3', toStage: 'S4'),
  ],
);

const _options = WorkflowFormOptions(
  companies: ['تابان'],
  modules: [],
  roles: ['Accounts Manager', 'Purchase Manager'],
  departments: [
    WorkflowTargetOption(id: 'All', label: 'همه واحدها', isGroup: true),
    WorkflowTargetOption(id: 'BUY', label: 'بازرگانی', parent: 'All'),
  ],
  employees: [
    WorkflowTargetOption(
        id: 'EMP-1',
        label: 'علی محمدی',
        department: 'BUY',
        designation: 'مدیر بازرگانی'),
  ],
);

/// A mutable design the route fake can rewrite, so the form -> save ->
/// diagram round trip is exercised against the same transitions the canvas
/// reads.
class _Store {
  _Store(this.design);
  late WorkflowDesign design;
  int loads = 0;
}

class _Workflows extends Fake implements WorkflowRepository {
  _Workflows(this.store);
  final _Store store;
  final saved = <Map<String, dynamic>>[];
  @override
  Future<WorkflowDesign> getDesign(String definition) async {
    store.loads++;
    return store.design;
  }

  @override
  Future<WorkflowFormOptions> getFormOptions() async => _options;
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved.add(config);
    return store.design;
  }
}

class _Automation extends Fake implements WorkflowAutomationRepository {
  _Automation(this.store);
  final _Store store;
  final routes = <Map<String, String>>[];
  @override
  bool get isLocal => false;
  @override
  Future<void> saveStageRoutes(
      {required String definition,
      required String stage,
      required Map<String, String> routes}) async {
    this.routes.add(routes);
    // Apply the change the way the server does: drop the old edge for each
    // action and add the new one.
    final actions = {'Approve': 'تأیید', 'Reject': 'رد', 'Return': 'بازگشت برای اصلاح'};
    final kept = store.design.transitions
        .where((e) => e.fromStage != stage)
        .toList(growable: true);
    for (final entry in routes.entries) {
      kept.removeWhere((e) =>
          e.fromStage == stage &&
          (e.condition['action']?.toString() ?? e.label) == entry.key);
      if (entry.value.isNotEmpty) {
        kept.add(WorkflowTransition(
            id: 'RT-${entry.key}',
            fromStage: stage,
            toStage: entry.value,
            label: actions[entry.key],
            condition: {'action': entry.key}));
      }
    }
    store.design = WorkflowDesign(
        workflow: store.design.workflow,
        stages: store.design.stages,
        transitions: kept);
  }
}

Future<(_Workflows, _Automation, WorkflowDesignerCubit)> _open(
    WidgetTester tester, String stageId, {WorkflowDesign? designOverride}) async {
  final store = _Store(designOverride ?? _design);
  final workflows = _Workflows(store);
  final automation = _Automation(store);
  final cubit =
      WorkflowDesignerCubit(repository: workflows, definition: 'WF-1');
  await cubit.load();
  final design = store.design;
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
              onPressed: () {
                final current = cubit.state.design ?? design;
                Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                            value: cubit,
                            child: StageSettingsPage(
                                stage: current.stages
                                    .firstWhere((stage) => stage.id == stageId),
                                design: current,
                                options: _options,
                                automation: automation))));
              },
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
  return (workflows, automation, cubit);
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
  test('stageRoutes reads the saved transitions as the single source', () {
    final routes = stageRoutes(_design, _design.stages.firstWhere((s) => s.id == 'S2'));
    expect(routes, {'Approve': 'S3'});
  });

  test('routeProblems flags a return to the end stage', () {
    final problems = routeProblems(
        design: _design,
        stage: _design.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'S3', 'Return': 'S4'});
    expect(problems, contains('مقصد بازگشت برای اصلاح نباید پایان فرایند باشد؛ یک ایستگاه قابل‌اجرای قبلی را انتخاب کنید.'));
  });

  test('routeProblems flags a self connection', () {
    final problems = routeProblems(
        design: _design,
        stage: _design.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'S2'});
    expect(problems, contains('مقصد «تأیید» نمی‌تواند خودِ این مرحله باشد.'));
  });

  test('routeProblems flags a deleted target', () {
    final problems = routeProblems(
        design: _design,
        stage: _design.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'GONE'});
    expect(problems, contains('مقصد «تأیید» به مرحله‌ای خارج از این گردش‌کار اشاره می‌کند؛ دوباره انتخاب کنید.'));
  });

  test('routeProblems flags a main route that loops without an end', () {
    // S2 -> S3 -> S2 with no end reachable.
    final loop = WorkflowDesign(
      workflow: _design.workflow,
      stages: [
        _stage('S0', WorkflowStageType.start, 'شروع', 1),
        _stage('S2', WorkflowStageType.approval, 'تأیید', 2,
            {'assignment_type': 'Direct Manager'}),
        _stage('S3', WorkflowStageType.userTask, 'ثبت سند', 3),
      ],
      transitions: const [
        WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S2'),
        WorkflowTransition(id: 'T2', fromStage: 'S2', toStage: 'S3',
            label: 'تأیید', condition: {'action': 'Approve'}),
        WorkflowTransition(id: 'T3', fromStage: 'S3', toStage: 'S2'),
      ],
    );
    final problems = routeProblems(
        design: loop,
        stage: loop.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'S3'});
    expect(problems, contains('مسیرهای اصلی حلقه‌ای بدون خروج به پایان فرایند می‌سازند؛ یک مسیر باید به پایان برسد.'));
  });

  test('routeProblems allows a correction loop that still reaches an end', () {
    // S2 approves to S3; S3 returns to S2 (correction) but S2 also ends.
    final correction = WorkflowDesign(
      workflow: _design.workflow,
      stages: [
        _stage('S0', WorkflowStageType.start, 'شروع', 1),
        _stage('S2', WorkflowStageType.approval, 'تأیید', 2,
            {'assignment_type': 'Direct Manager'}),
        _stage('S3', WorkflowStageType.userTask, 'ثبت سند', 3),
        _stage('S4', WorkflowStageType.end, 'پایان', 4),
      ],
      transitions: const [
        WorkflowTransition(id: 'T1', fromStage: 'S0', toStage: 'S2'),
        WorkflowTransition(id: 'T2', fromStage: 'S2', toStage: 'S4',
            label: 'تأیید', condition: {'action': 'Approve'}),
        WorkflowTransition(id: 'T3', fromStage: 'S3', toStage: 'S2',
            label: 'بازگشت برای اصلاح', condition: {'action': 'Return'}),
      ],
    );
    final problems = routeProblems(
        design: correction,
        stage: correction.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'S4'});
    expect(problems, isEmpty);
  });

  test('routeProblems is empty for a valid design', () {
    final problems = routeProblems(
        design: _design,
        stage: _design.stages.firstWhere((s) => s.id == 'S2'),
        routes: {'Approve': 'S3'});
    expect(problems, isEmpty);
  });

  testWidgets('a route chosen in the form is saved and shown on the diagram',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation, cubit) = await _open(tester, 'S2');
    // The Approve route already points at the user task S3 (ثبت سند).
    await _tap(tester, find.byKey(const ValueKey('approval-diagram-expand')));
    final preview = find.byKey(const ValueKey('approval-diagram-preview'));
    await _scrollToFinder(tester, preview);
    expect(find.byKey(const ValueKey('approval-preview-target-Approve-S3')),
        findsOneWidget);
    // Change the Approve target in the form to the end stage and save.
    await _tap(tester, find.byKey(const ValueKey('approval-route-Approve')));
    await tester.enterText(
        find.widgetWithText(TextField, 'جستجو در مراحل گردش کار...'),
        'پایان فرایند');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('پایان فرایند').last);
    await _tap(tester, find.text('ذخیره'));
    await tester.pumpAndSettle();
    // The form saved only the changed route.
    expect(automation.routes.single, {'Approve': 'S4'});
    // The page popped; reopen the same stage. The saved transition is the
    // single source, so the diagram now shows the new target.
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('approval-diagram-expand')));
    await _scrollToFinder(tester, preview);
    expect(find.byKey(const ValueKey('approval-preview-target-Approve-S4')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('approval-preview-target-Approve-S3')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('a return to the end is blocked before save at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workflows, automation, _) = await _open(tester, 'S2');
      // Return is allowed by default for an approval; point it at the end stage.
      await _tap(tester, find.byKey(const ValueKey('approval-route-Return')));
      await tester.enterText(
          find.widgetWithText(TextField, 'جستجو در مراحل گردش کار...'),
          'پایان فرایند');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('پایان فرایند').last);
      await _tap(tester, find.text('ذخیره'));
      expect(
          find.text('مقصد بازگشت برای اصلاح نباید پایان فرایند باشد؛ یک ایستگاه قابل‌اجرای قبلی را انتخاب کنید.'),
          findsOneWidget);
      expect(workflows.saved, isEmpty);
      expect(automation.routes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
