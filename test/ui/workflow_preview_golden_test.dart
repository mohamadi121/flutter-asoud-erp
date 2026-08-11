import 'package:asoud_erp/core/theme/asoud_theme.dart';
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

class _PreviewRepository implements WorkflowRepository {
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
  Future<WorkflowDesign> getDesign(String definition) async => _design();

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

  WorkflowDesign _design({bool includeUserTask = false}) => WorkflowDesign(
        workflow: WorkflowDefinition(
          id: 'WF-1405-001',
          code: 'WF-1405-001',
          title: 'فرایند درخواست خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: includeUserTask ? 1 : 0,
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
          if (includeUserTask)
            const WorkflowStage(
              id: 'TASK-1',
              key: 'task-1',
              type: WorkflowStageType.userTask,
              title: 'وظیفه کاربر',
              sequence: 1,
              configurationComplete: false,
            ),
        ],
        transitions: includeUserTask
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

Widget _app(Widget child) => RepositoryProvider<WorkflowRepository>.value(
      value: _PreviewRepository(),
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
    expect(find.text('وظیفه کاربر'), findsOneWidget);
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
      expect(find.text('ذخیره مرحله'), findsOneWidget);
    });
  }
}
