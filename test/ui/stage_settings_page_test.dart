import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/document_template.dart';
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
  ],
);

class _Workflows extends Fake implements WorkflowRepository {
  final saved = <Map<String, dynamic>>[];
  @override
  Future<WorkflowDesign> getDesign(String definition) async => _design;
  @override
  Future<WorkflowFormOptions> getFormOptions() async => _options;
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved.add(config);
    return _design;
  }
}

const _template = DocumentTemplate(
    name: 'TPL-1',
    title: 'سند هزینه خرید',
    module: 'Finance',
    documentType: 'Journal Entry',
    description: 'ثبت سند هزینه');

class _Automation extends Fake implements WorkflowAutomationRepository {
  final routes = <Map<String, String>>[];
  @override
  Future<void> saveStageRoutes(
      {required String definition,
      required String stage,
      required Map<String, String> routes}) async {
    this.routes.add(routes);
  }

  @override
  Future<DocumentTemplateOptions> templateOptions(
          {required String company, String? workflow}) async =>
      const DocumentTemplateOptions(modules: [
        DocumentModule(key: 'Finance', label: 'مالی', types: [
          DocumentTypeOption(key: 'Journal Entry', label: 'سند حسابداری')
        ]),
      ]);

  @override
  Future<List<DocumentTemplate>> templates(
          {required String company,
          String kind = 'custom',
          String? module,
          String? documentType,
          String search = ''}) async =>
      kind == 'custom' ? [_template] : [];
}

Future<(_Workflows, _Automation)> _open(
    WidgetTester tester, String stageId) async {
  final workflows = _Workflows();
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
                              stage: _design.stages
                                  .firstWhere((stage) => stage.id == stageId),
                              design: _design,
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  final dropdown =
      find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  await _tap(
      tester,
      find.descendant(
          of: dropdown,
          matching: find.byType(DropdownButtonFormField<String>)));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('approval stage saves decisions and a reject route at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workflows, automation) = await _open(tester, 'S2');
      expect(find.text('تأیید / رد'), findsWidgets);
      expect(find.text('مدیر مستقیم'), findsOneWidget);
      expect(find.text('امکان تأیید'), findsOneWidget);
      await _tap(tester, find.text('الزام ثبت توضیح هنگام رد'));
      await _choose(tester, 'در صورت رد', 'رد درخواست');
      await _tap(tester, find.text('ذخیره'));
      final config = workflows.saved.single;
      expect(config['assignment_type'], 'Direct Manager');
      expect(config['reject_comment_required'], isTrue);
      expect(config['allow_reject'], isTrue);
      // The approve route did not change; only the reject route is sent.
      expect(automation.routes.single, {'Reject': 'S5'});
      expect(find.byType(StageSettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a unit and a specific person become an Employee assignment',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, 'S2');
    await _tap(tester, find.text('واحد سازمانی'));
    await _tap(tester, find.text('انتخاب واحد'));
    // The ERPNext root group is skipped; its children are listed.
    expect(find.text('همه واحدها'), findsNothing);
    expect(find.text('واحد درخواست‌کننده'), findsOneWidget);
    await _tap(tester, find.text('بازرگانی'));
    await _tap(tester, find.text('تأیید انتخاب'));
    expect(
        find.text(
            'این مرحله برای تمامی افراد واحد انتخاب‌شده قابل انجام خواهد بود.'),
        findsOneWidget);
    await _tap(tester, find.text('یک فرد مشخص'));
    await _tap(tester, find.text('انتخاب فرد'));
    expect(find.text('مدیر بازرگانی'), findsOneWidget);
    await _tap(tester, find.text('علی محمدی'));
    await _tap(tester, find.text('تأیید انتخاب'));
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['assignment_type'], 'Employee');
    expect(workflows.saved.single['approver_employees'], ['EMP-1']);
  });

  testWidgets('sub-units open from their parent unit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, _) = await _open(tester, 'S2');
    await _tap(tester, find.text('واحد سازمانی'));
    await _tap(tester, find.text('انتخاب واحد'));
    await _tap(tester, find.byTooltip('زیرمجموعه‌ها'));
    await _tap(tester, find.text('واحد خزانه'));
    await _tap(tester, find.text('تأیید انتخاب'));
    expect(find.text('واحد خزانه'), findsOneWidget);
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['approver_departments'], ['TRE']);
  });

  testWidgets('automatic stage creates a document from a picked template',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, 'S3');
    expect(find.text('اقدام خودکار'), findsWidgets);
    expect(find.text('به‌زودی'), findsOneWidget); // external API is not offered
    await _tap(tester, find.text('ایجاد سند'));
    await _tap(tester, find.text('ذخیره'));
    expect(find.text('الگوی سند را انتخاب کنید.'), findsOneWidget);
    await _tap(tester, find.text('انتخاب').first);
    expect(find.text('تنظیمات ایجاد سند'), findsWidgets);
    await _tap(tester, find.text('انتخاب الگو'));
    await _tap(tester, find.text('سند هزینه خرید'));
    await _tap(tester, find.text('تأیید انتخاب'));
    await _tap(tester, find.text('ذخیره').last);
    expect(find.text('سند هزینه خرید'), findsOneWidget);
    await _choose(tester, 'در صورت خطا', 'رد درخواست');
    await _tap(tester, find.text('ذخیره'));
    final config = workflows.saved.single;
    expect(config['action_type'], 'Create Document');
    expect(config['document_template'], 'TPL-1');
    expect(config['transfer_values'], isTrue);
    expect(automation.routes.single, {'Error': 'S5'});
  });

  testWidgets('change status stage keeps its label and main route',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workflows, automation) = await _open(tester, 'S3');
    expect(find.text('در حال ثبت'), findsOneWidget);
    await _tap(tester, find.text('تأیید شده'));
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['request_status'], 'تأیید شده');
    expect(automation.routes, isEmpty);
  });
}
