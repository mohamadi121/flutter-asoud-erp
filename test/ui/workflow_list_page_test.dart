import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _WorkflowRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
          {String? beforeStage}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> getDesign(String definition) =>
      throw UnimplementedError();

  @override
  Future<WorkflowStage> saveStartSettings(
          {required String definition,
          required String triggerType,
          required List<String> initiatorRoles,
          required String subjectSource,
          required String passMode}) =>
      throw UnimplementedError();

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
  }) async =>
      const WorkflowDefinition(
        id: 'WF-1405-001',
        code: 'WF-1405-001',
        title: 'فرایند آزمایشی',
        targetDoctype: 'Material Request',
        status: WorkflowDefinitionStatus.inactive,
        isLocked: true,
        version: 1,
        stepsCount: 0,
        modified: null,
      );

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: ['شرکت نمونه'],
        modules: [
          WorkflowModuleOption(
            key: 'Purchase',
            doctypes: [
              WorkflowDoctypeOption(name: 'Material Request', available: true),
            ],
          ),
        ],
      );
  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async =>
      const [
        WorkflowDefinition(
          id: 'WF-1404-001',
          code: 'WF-1404-001',
          title: 'فرایند خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          iconKey: 'purchase',
        ),
        WorkflowDefinition(
          id: 'WF-1404-002',
          code: 'WF-1404-002',
          title: 'درخواست مرخصی',
          targetDoctype: 'Leave Application',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: 0,
          modified: null,
          pendingReason: 'برای اجرا به HRMS نیاز دارد',
          missingRequirements: ['HRMS'],
          iconKey: 'leave',
        ),
      ];
}

void main() {
  testWidgets('صفحه گردش‌کار در عرض‌های موبایل overflow ندارد', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepositoryProvider<WorkflowRepository>.value(
        value: _WorkflowRepository(),
        child: const MaterialApp(
          locale: Locale('fa'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: WorkflowListPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('گردش‌کارها'), findsOneWidget);
    expect(find.text('فرایند خرید کالا'), findsOneWidget);
    expect(find.text('نیازمند تکمیل'), findsOneWidget);
    expect(find.text('ایجاد گردش‌کار جدید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('دکمه ایجاد به صفحه فرم مرحله بعد می‌رود', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<WorkflowRepository>.value(
        value: _WorkflowRepository(),
        child: const MaterialApp(home: WorkflowListPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ایجاد گردش‌کار جدید'));
    await tester.pumpAndSettle();

    expect(find.text('اطلاعات پایه فرایند را وارد کنید'), findsOneWidget);
  });
}
