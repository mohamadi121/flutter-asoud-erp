import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
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

const _template = DocumentTemplate(
    name: 'TPL-1',
    title: 'سند هزینه خرید',
    module: 'Finance',
    documentType: 'Journal Entry',
    description: 'ثبت سند هزینه');

class _FormClient extends Fake implements FrappeApiClient {
  final calls = <Map<String, dynamic>>[];
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'designer', fullName: 'طراح', roles: ['System Manager']);
  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    calls.add({'method': method, ...?data});
    expect(method, 'asoud_erp.api.v1.forms.get_form');
    return {'message': {'ok': true, 'meta': {'api_version': 'v1'}, 'data': {
      'schema': {'kind': 'Request', 'title': 'درخواست مرخصی', 'sections': [
        {'id': 'main', 'fields': [{'key': 'note', 'label': 'شرح درخواست', 'type': 'Text'}]}
      ]}
    }}};
  }
}

class _Automation extends Fake implements WorkflowAutomationRepository {
  @override
  final _FormClient client = _FormClient();
  @override
  bool get isLocal => false;
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

Future<void> _choose(WidgetTester tester, String label, String option) async {
  await _scrollToFinder(tester, find.text(label));
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
  testWidgets('unrelated approval edits retain every previously saved role', (tester) async {
    final design = WorkflowDesign(workflow: _design.workflow, transitions: _design.transitions,
      stages: [for (final stage in _design.stages) stage.id == 'S2'
        ? stage.copyWith(config: {...stage.config, 'assignment_type': 'Role',
          'approver_roles': ['Accounts Manager', 'Purchase Manager']}) : stage]);
    final (workflows, _) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('ذخیره').last);
    expect(workflows.saved.single['approver_roles'], ['Accounts Manager', 'Purchase Manager']);
  });
  testWidgets('unrelated approval edits retain every previously saved department', (tester) async {
    final design = WorkflowDesign(workflow: _design.workflow, transitions: _design.transitions,
      stages: [for (final stage in _design.stages) stage.id == 'S2'
        ? stage.copyWith(config: {...stage.config, 'assignment_type': 'Department',
          'approver_departments': ['FIN', 'BUY']}) : stage]);
    final (workflows, _) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('ذخیره').last);
    expect(workflows.saved.single['approver_departments'], ['FIN', 'BUY']);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('approval diagram preview uses actual routes at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (workflows, automation) = await _open(tester, 'S2');
      await _tap(tester, find.byKey(const ValueKey('approval-diagram-expand')));
      final preview = find.byKey(const ValueKey('approval-diagram-preview'));
      await _scrollToFinder(tester, preview);
      expect(find.descendant(of: preview, matching: find.text('ثبت سند')), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.text('پایان فرایند')), findsNothing);
      expect(find.byKey(const ValueKey('approval-preview-target-Approve-S3')), findsOneWidget);
      expect(find.byKey(const ValueKey('approval-preview-unset-Reject')), findsOneWidget);
      expect(workflows.saved, isEmpty);
      expect(automation.routes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('approval preview changes with route selection and opens the existing stage form', (tester) async {
    final (workflows, automation) = await _open(tester, 'S2');
    await _tap(tester, find.byKey(const ValueKey('approval-diagram-expand')));
    await _tap(tester, find.byKey(const ValueKey('approval-preview-unset-Reject')));
    await tester.enterText(find.widgetWithText(TextField, 'جستجو در مراحل گردش کار...'), 'رد درخواست');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('رد درخواست').last);
    expect(find.byKey(const ValueKey('approval-preview-target-Reject-S5')), findsOneWidget);
    expect(find.byKey(const ValueKey('approval-preview-unset-Reject')), findsNothing);
    expect(workflows.saved, isEmpty);
    expect(automation.routes, isEmpty);
    await _tap(tester, find.byKey(const ValueKey('approval-preview-target-Approve-S3')));
    await _scrollToFinder(tester, find.text('در حال ثبت'));
    expect(find.text('در حال ثبت'), findsOneWidget);
    await _tap(tester, find.byTooltip('بازگشت'));
    expect(find.byKey(const ValueKey('approval-preview-target-Reject-S5')), findsOneWidget);
    expect(workflows.saved, isEmpty);
    expect(automation.routes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('approval source preview uses Start revision and never submits an entry', (tester) async {
    final design = WorkflowDesign(workflow: _design.workflow, transitions: _design.transitions,
        stages: [for (final stage in _design.stages) stage.id == 'S0'
            ? stage.copyWith(config: {'submission_source': {'form': 'form-1', 'revision': 'rev-1', 'title': 'درخواست مرخصی'}})
            : stage]);
    final (_, automation) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.byKey(const ValueKey('approval-source-preview')));
    final preview = tester.widget<FormFieldsView>(find.byType(FormFieldsView));
    expect(preview.enabled, isFalse);
    expect(preview.snapshot, isTrue);
    expect(preview.values, isEmpty);
    expect(automation.client.calls.single['name'], 'form-1');
    expect(automation.client.calls.single['revision_name'], 'rev-1');
    expect(automation.client.calls.single['method'], endsWith('.get_form'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unrelated approval edit preserves an already-disabled stored route', (tester) async {
    final design = WorkflowDesign(workflow: _design.workflow,
        stages: [for (final stage in _design.stages) stage.id == 'S2'
            ? stage.copyWith(config: {...stage.config, 'allow_reject': false}) : stage],
        transitions: [..._design.transitions, const WorkflowTransition(id: 'R1',
            fromStage: 'S2', toStage: 'S5', label: 'رد', condition: {'action': 'Reject'})]);
    final (workflows, automation) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['allow_reject'], isFalse);
    expect(automation.routes, isEmpty);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('approval information is readonly and owner is not duplicated at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, 'S2');
      await _scrollToFinder(tester, find.text('اطلاعات موردنیاز برای تأیید'));
      expect(find.text('فرم اصلی درخواست'), findsOneWidget);
      expect(find.text('فرم قابل پیش‌نمایش در شروع انتخاب نشده است.'), findsOneWidget);
      expect(find.byKey(const ValueKey('approval-source-preview')), findsNothing);
      await _scrollToFinder(tester, find.text('مسئول تأیید *'));
      expect(find.text('مسئول تأیید *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('new pending approval defaults to All without converting legacy Any', (tester) async {
    final pending = WorkflowStage(id: 'S2', key: 'S2', type: WorkflowStageType.approval,
        title: 'تأیید مدیر مستقیم', sequence: 3, configurationComplete: false);
    final design = WorkflowDesign(workflow: _design.workflow,
        stages: [for (final stage in _design.stages) stage.id == 'S2' ? pending : stage],
        transitions: _design.transitions);
    final (workflows, _) = await _open(tester, 'S2', designOverride: design);
    await _tap(tester, find.text('ذخیره'));
    expect(workflows.saved.single['approval_mode'], 'All');
  });

  for (final confirm in [false, true]) {
    testWidgets('disabling an existing Reject route requires confirmation: $confirm', (tester) async {
      final design = WorkflowDesign(workflow: _design.workflow, stages: _design.stages,
          transitions: [..._design.transitions, const WorkflowTransition(id: 'R1',
              fromStage: 'S2', toStage: 'S5', label: 'رد', condition: {'action': 'Reject'})]);
      final (workflows, automation) = await _open(tester, 'S2', designOverride: design);
      await _tap(tester, find.text('امکان رد'));
      expect(find.text('غیرفعال‌کردن تصمیم'), findsOneWidget);
      if (confirm) {
        await tester.tap(find.text('تأیید غیرفعال‌سازی'));
      } else {
        await tester.tap(find.widgetWithText(TextButton, 'انصراف').last);
      }
      await tester.pumpAndSettle();
      await _tap(tester, find.text('ذخیره'));
      expect(workflows.saved.single['allow_reject'], !confirm);
      expect(workflows.saved.single['approval_mode'], 'Any');
      if (confirm) {
        expect(automation.routes.single, {'Reject': ''});
      } else {
        expect(automation.routes, isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('user action keeps report and four independent capabilities at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workflows, automation) = await _open(tester, 'S1');
      expect(find.text('روش اول: ثبت گزارش ساده'), findsOneWidget);
      expect(find.byKey(const ValueKey('action-result-preview')), findsNothing);
      await _tap(tester, find.text('تنظیمات تکمیلی (اختیاری)'));
      expect(find.byType(BottomSheet), findsNothing);
      for (final label in ['دسترسی به درخواست اصلی', 'امکان افزودن پیوست', 'ذخیره پیش‌نویس', 'امکان واگذاری مجدد']) {
        await _scrollToFinder(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      await _tap(tester, find.text('امکان واگذاری مجدد'));
      await _tap(tester, find.text('ذخیره پیش‌نویس'));
      await _tap(tester, find.text('دسترسی به درخواست اصلی'));
      expect(find.text('فقط مشاهده درخواست'), findsNothing);
      await _tap(tester, find.text('ذخیره'));
      final saved = workflows.saved.single;
      expect(saved['simple_result_style'], 'Report');
      expect(saved['allow_reassign'], isTrue);
      expect(saved['allow_draft'], isFalse);
      expect(saved['allow_original_access'], isFalse);
      expect(saved['allow_add_attachments'], isFalse);
      expect(automation.routes, isEmpty); // Canvas, not assignment, owns routes.
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 390.0]) {
    testWidgets('approval stage saves decisions and a reject route at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workflows, automation) = await _open(tester, 'S2');
      expect(find.text('تأیید / رد'), findsWidgets);
      await _scrollToFinder(tester, find.text('مدیر مستقیم'));
      expect(find.text('مدیر مستقیم'), findsOneWidget);
      await _scrollToFinder(tester, find.text('امکان تأیید'));
      expect(find.text('امکان تأیید'), findsOneWidget);
      await _tap(tester, find.text('تنظیمات اضافی (اختیاری)'));
      expect(find.text('طبق قواعد سامانه، دلیل رد همواره الزامی است.'), findsOneWidget);
      await _tap(tester, find.text('تنظیمات اضافی (اختیاری)'));
      await _tap(tester, find.text('پایان فرایند (رد درخواست)'));
      // The route sheet selects the stage type before the concrete stage.
      await _tap(tester, find.text('پایان فرایند'));
      await _tap(tester, find.text('رد درخواست'));
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
