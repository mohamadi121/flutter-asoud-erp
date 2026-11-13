import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_wait_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _WaitRepository extends Mock implements WorkflowWaitRepository {}

class _PreviewRepository implements WorkflowRepository {
  _PreviewRepository({this.includeCondition = false});

  final bool includeCondition;
  Map<String, dynamic>? connectedCondition;
  String? connectedFromStage, connectedToStage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
          {String? beforeStage}) async =>
      const [
        WorkflowFieldOption(name: 'status', label: 'وضعیت', type: 'Select'),
        WorkflowFieldOption(
            name: 'grand_total', label: 'مبلغ کل', type: 'Currency'),
      ];

  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) async =>
      _design(includeUserTask: true);

  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) async =>
      _design(includeUserTask: true);

  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) async =>
      _design(includeUserTask: true);

  @override
  Future<WorkflowDesign> connectStages({
    required String definition,
    required String fromStage,
    required String toStage,
    required String action,
    Map<String, dynamic> condition = const {},
  }) async {
    connectedFromStage = fromStage;
    connectedToStage = toStage;
    connectedCondition = condition;
    return _design(includeCondition: includeCondition);
  }

  @override
  Future<WorkflowDesign> getDesign(String definition) async =>
      _design(includeCondition: includeCondition);

  @override
  Future<WorkflowStage> saveStartSettings(
          {required String definition,
          required String triggerType,
          required List<String> initiatorRoles,
          required String subjectSource,
          required String passMode}) async =>
      WorkflowStage(
        id: 'START-1',
        key: 'start-1',
        type: WorkflowStageType.start,
        title: 'شروع',
        sequence: 0,
        configurationComplete: true,
        config: {
          'trigger_type': triggerType,
          'initiator_roles': initiatorRoles,
          'subject_source': subjectSource,
          'pass_mode': passMode,
        },
      );

  WorkflowDesign _design(
          {bool includeUserTask = false, bool includeCondition = false}) =>
      WorkflowDesign(
        workflow: WorkflowDefinition(
          id: 'WF-1405-001',
          code: 'WF-1405-001',
          title: 'فرایند درخواست خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: includeUserTask || includeCondition ? 1 : 0,
          modified: DateTime(2026, 8, 8),
        ),
        stages: [
          const WorkflowStage(
            id: 'START-1',
            key: 'start-1',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 0,
            configurationComplete: false,
            config: {
              'trigger_type': 'Manual',
              'initiator_roles': ['Accounts Manager'],
              'subject_source': 'Referenced Document',
              'pass_mode': 'Direct',
            },
          ),
          if (includeCondition)
            const WorkflowStage(
              id: 'CONDITION-1',
              key: 'condition-1',
              type: WorkflowStageType.condition,
              title: 'شرط درخواست',
              sequence: 1,
              configurationComplete: true,
            ),
          if (includeUserTask || includeCondition)
            WorkflowStage(
              id: 'TASK-1',
              key: 'task-1',
              type: WorkflowStageType.userTask,
              title: 'وظیفه کاربر',
              sequence: includeCondition ? 2 : 1,
              configurationComplete: false,
            ),
        ],
        transitions: includeCondition
            ? const [
                WorkflowTransition(
                    id: 'TR-1', fromStage: 'START-1', toStage: 'CONDITION-1')
              ]
            : includeUserTask
                ? const [
                    WorkflowTransition(
                        id: 'TR-1', fromStage: 'START-1', toStage: 'TASK-1')
                  ]
                : const [],
      );

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: ['شرکت نمونه توسعه آریا'],
        roles: ['Accounts Manager', 'Accounts User', 'Purchase Manager'],
        modules: [
          WorkflowModuleOption(key: 'Purchase', doctypes: [
            WorkflowDoctypeOption(name: 'Material Request', available: true),
            WorkflowDoctypeOption(name: 'Purchase Order', available: true),
          ]),
          WorkflowModuleOption(key: 'Accounting', doctypes: [
            WorkflowDoctypeOption(name: 'Payment Request', available: true),
            WorkflowDoctypeOption(name: 'Expense Claim', available: false),
          ]),
          WorkflowModuleOption(key: 'HR', doctypes: [
            WorkflowDoctypeOption(name: 'Leave Application', available: false),
            WorkflowDoctypeOption(name: 'Job Applicant', available: false),
          ]),
        ],
      );

  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async =>
      [
        WorkflowDefinition(
          id: 'WF-1405-001',
          code: 'WF-1405-001',
          title: 'فرایند خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: DateTime(2026, 8, 8),
          iconKey: 'purchase',
        ),
        WorkflowDefinition(
          id: 'WF-1405-002',
          code: 'WF-1405-002',
          title: 'درخواست مرخصی',
          targetDoctype: 'Leave Application',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: 0,
          modified: DateTime(2026, 8, 7),
          pendingReason: 'نیازمند نصب HRMS',
          missingRequirements: const ['HRMS'],
          iconKey: 'leave',
        ),
        WorkflowDefinition(
          id: 'WF-1405-003',
          code: 'WF-1405-003',
          title: 'پرداخت هزینه‌ها',
          targetDoctype: 'Payment Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 2,
          stepsCount: 5,
          modified: DateTime(2026, 8, 6),
          iconKey: 'expense',
        ),
        WorkflowDefinition(
          id: 'WF-1405-004',
          code: 'WF-1405-004',
          title: 'درخواست پشتیبانی',
          targetDoctype: 'Issue',
          status: WorkflowDefinitionStatus.archived,
          isLocked: false,
          version: 1,
          stepsCount: 3,
          modified: DateTime(2026, 8, 5),
          iconKey: 'support',
        ),
      ];

  @override
  Future<WorkflowDefinition> createDraft({
    required String title,
    required String moduleKey,
    required String targetDoctype,
    required String creationMode,
    String? description,
    String? company,
    String? iconKey,
    String? colorHex,
  }) =>
      throw UnimplementedError();
}

Widget _app(Widget child, {WorkflowRepository? repository}) =>
    RepositoryProvider<WorkflowRepository>.value(
      value: repository ?? _PreviewRepository(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final vazirmatn = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([vazirmatn.load(), materialIcons.load()]);
  });

  testWidgets('workflow list preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const WorkflowListPage()));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/workflow_list_390.png'));
  }, tags: 'golden');

  testWidgets('workflow form preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const WorkflowFormPage()));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/workflow_form_390.png'));
  }, tags: 'golden');

  testWidgets('workflow designer preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        _app(const WorkflowDesignerPage(definition: 'WF-1405-001')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/workflow_designer_390.png'));
  }, tags: 'golden');

  for (final branch in [
    (label: 'شرط برقرار است', result: true),
    (label: 'شرط برقرار نیست', result: false),
  ]) {
    testWidgets('condition connection sends ${branch.label} result',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PreviewRepository(includeCondition: true);
      await tester.pumpWidget(_app(
        const WorkflowDesignerPage(definition: 'WF-1405-001'),
        repository: repository,
      ));
      await tester.pumpAndSettle();

      // The node-side chain was intentionally removed. Keep verifying the
      // existing routing contract independently of that retired control.
      final node = find.byKey(const ValueKey('workflow-node-CONDITION-1'));
      expect(find.descendant(of: node,
        matching: find.byIcon(Icons.add_link_rounded)), findsNothing);
      final cubit = BlocProvider.of<WorkflowDesignerCubit>(tester.element(node));
      await cubit.connectStages(fromStage: 'CONDITION-1', toStage: 'TASK-1',
        action: branch.label, condition: {'result': branch.result});
      await tester.pumpAndSettle();

      expect(repository.connectedFromStage, 'CONDITION-1');
      expect(repository.connectedToStage, 'TASK-1');
      expect(repository.connectedCondition, {'result': branch.result});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('six stage buttons preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        _app(const WorkflowDesignerPage(definition: 'WF-1405-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('افزودن مرحله').last);
    await tester.pumpAndSettle();
    expect(find.text('اقدام کاربر'), findsOneWidget);
    expect(find.text('انتظار و زمان‌بندی'), findsOneWidget);
    expect(find.text('پایان فرایند'), findsOneWidget);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/workflow_stage_picker_390.png'));
  }, tags: 'golden');

  for (final type in WorkflowStageType.values
      .where((type) => type != WorkflowStageType.start)) {
    testWidgets('stage settings ${type.name} has no overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PreviewRepository();
      final waitRepository = _WaitRepository();
      when(() => waitRepository.draft('WF-1405-001', 'STAGE-1'))
          .thenAnswer((_) async => null);
      when(() => waitRepository.options('WF-1405-001', 'STAGE-1'))
          .thenAnswer((_) async => {
                'wait_version': 1,
                'execution_ready': true,
                'time_zone': 'Asia/Tehran',
                'zone_source': 'System',
                'output_valid': true,
                'output_label': 'ادامه فرایند',
                'fields': <Map<String, dynamic>>[],
              });
      await tester.pumpWidget(
        RepositoryProvider<WorkflowRepository>.value(
          value: repository,
          child: BlocProvider(
            create: (_) => WorkflowDesignerCubit(
              repository: repository,
              definition: 'WF-1405-001',
            ),
            child: MaterialApp(
              theme: AsoudTheme.light,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: WorkflowStageSettingsPage(
                  waitRepository: waitRepository,
                  stage: WorkflowStage(
                    id: 'STAGE-1',
                    key: 'stage-1',
                    type: type,
                    title: 'تنظیم مرحله',
                    sequence: 1,
                    configurationComplete: false,
                  ),
                  roles: const ['Accounts Manager', 'Accounts User'],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(type == WorkflowStageType.wait
          ? 'اعتبارسنجی و ذخیره' : 'ذخیره مرحله'), findsOneWidget);
    });
  }
}
