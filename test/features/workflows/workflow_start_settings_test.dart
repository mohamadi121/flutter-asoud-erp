import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_start_settings.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_form_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_manual_start_dialog.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_start_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const definition = WorkflowDefinition(
    id: 'created',
    code: 'created',
    title: 'بررسی درخواست',
    targetDoctype: 'ASOUD Workflow Request',
    status: WorkflowDefinitionStatus.inactive,
    isLocked: true,
    version: 1,
    stepsCount: 0,
    modified: null,
    company: 'company');

class Repository extends Fake
    implements WorkflowRepository, WorkflowStartSettingsRepository {
  int creates = 0, saves = 0;
  bool failFirst = false;
  WorkflowStartSettings? saved;
  @override
  bool get localStartSettings => false;
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
          companies: ['company'],
          roles: ['System Manager', 'Employee'],
          modules: [WorkflowModuleOption(key: 'HR', doctypes: [])]);
  @override
  Future<WorkflowDesign> getDesign(String id) async =>
      WorkflowDesign(workflow: definition, stages: [
        WorkflowStage(
            id: 'start',
            key: 'start',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 0,
            configurationComplete: true,
            config: const WorkflowStartSettings(manual: true).storedConfig)
      ], transitions: const []);
  @override
  Future<WorkflowDefinition> createDraft(
      {required String title,
      required String moduleKey,
      required String targetDoctype,
      required String creationMode,
      String? description,
      String? company,
      String? iconKey,
      String? colorHex}) async {
    creates++;
    return definition;
  }

  @override
  Future<WorkflowDefinition> saveRequestTypeInfo(
          {required String definition, required RequestTypeInfo info}) async =>
      (await getDesign(definition)).workflow;
  @override
  Future<WorkflowStage> configureStart(
      String definition, WorkflowStartSettings settings) async {
    saves++;
    if (failFirst && saves == 1) {
      throw const ApiException(
          kind: ApiFailureKind.validation,
          message: 'انتخاب منبع تغییر کرده است.');
    }
    saved = settings;
    return WorkflowStage(
        id: 'start',
        key: 'start',
        type: WorkflowStageType.start,
        title: 'شروع',
        sequence: 0,
        configurationComplete: true,
        config: settings.storedConfig);
  }
}

class AtomicRepository extends Repository implements WorkflowDraftStartRepository {
  int validations = 0, initialized = 0;
  bool reject = false;
  @override
  Future<void> validateStartSelection(String company, WorkflowStartSettings settings, {String? definition}) async {
    validations++;
    if (reject) throw const ApiException(kind: ApiFailureKind.validation, message: 'نسخهٔ فرم تغییر کرده است.');
  }
  @override
  Future<WorkflowDefinition> createInitializedDraft(Map<String, dynamic> info, WorkflowStartSettings settings) async {
    initialized++;
    saved = settings;
    return definition;
  }
}

class AtomicClient extends Fake implements FrappeApiClient {
  bool omitSavedStart = false;
  final methods = <String>[];
  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    methods.add(method);
    if (method.endsWith('save_start_settings')) return {'message': {'ok': true, 'data': {'valid': true}}};
    expect(method, 'asoud_erp.api.v1.workflow.create_workflow_draft');
    return {'message': {'ok': true, 'data': {
      'name': 'created', 'workflow_code': 'WF-test', 'workflow_title': 'درخواست جدید',
      'company': 'company', 'module_key': 'HR', 'target_doctype': 'ASOUD Workflow Request',
      'status': 'Inactive', 'readiness_status': 'Pending', 'is_locked': true,
      'version_no': 1, 'steps_count': 0, 'missing_requirements': [],
      if (!omitSavedStart) 'start_settings': {
        ...Map<String, dynamic>.from(data!['start_settings'] as Map), 'start_settings_version': 1,
      },
    }}};
  }
}

class Client extends Fake implements FrappeApiClient {
  int calls = 0;
  Map<String, dynamic>? sent;
  bool protocolFailure = false;
  Completer<void>? hold;
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.workflow_runtime.start_workflow_instance');
    calls++;
    sent = data;
    await hold?.future;
    if (protocolFailure) throw const ApiException.protocol();
    return {
      'message': {
        'ok': true,
        'data': {'name': 'instance', 'status': 'Running'}
      }
    };
  }
}

class LegacyRepository extends Repository {
  @override
  Future<WorkflowDesign> getDesign(String id) async =>
      WorkflowDesign(workflow: definition, stages: [
        WorkflowStage(
            id: 'start',
            key: 'start',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 0,
            configurationComplete: false,
            config: const {'trigger_type': 'Manual'})
      ], transitions: const []);
}

void main() {
  test('initialized draft verifies the saved Start from one transaction response', () async {
    final client = AtomicClient();
    final repository = FrappeWorkflowRepository(client);
    const settings = WorkflowStartSettings(source: {'form': 'leave', 'revision': 'published'});
    await repository.validateStartSelection('company', settings);
    final result = await repository.createInitializedDraft({'workflow_title': 'درخواست جدید', 'company': 'company'}, settings);
    expect(result.id, 'created');
    expect(client.methods, ['asoud_erp.api.v1.workflow.save_start_settings', 'asoud_erp.api.v1.workflow.create_workflow_draft']);
  });
  test('a draft response without confirmed Start is never reported as saved', () async {
    final client = AtomicClient()..omitSavedStart = true;
    await expectLater(FrappeWorkflowRepository(client).createInitializedDraft({},
      const WorkflowStartSettings(manual: true)), throwsA(isA<ApiException>()));
  });
  test('atomic form draft preserves source and route, never runs a second start save', () async {
    final repository = AtomicRepository();
    final cubit = WorkflowFormCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('درخواست جدید');
    cubit.changeStart(const WorkflowStartSettings(source: {'form': 'leave', 'revision': 'published'}, sourceRoute: 'Available'));
    await cubit.submit();
    expect(cubit.state.status, WorkflowFormStatus.success);
    expect(repository.initialized, 1);
    expect(repository.creates, 0);
    expect(repository.saves, 0);
    expect(repository.saved!.manual, isFalse);
    expect(repository.saved!.source!['form'], 'leave');
    expect(repository.saved!.copyWith(roles: ['Employee']).sourceRoute, 'Available');
  });
  test('preflight rejection creates nothing and keeps the selected form visible', () async {
    final repository = AtomicRepository()..reject = true;
    final cubit = WorkflowFormCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('درخواست جدید');
    cubit.changeStart(const WorkflowStartSettings(source: {'form': 'leave', 'revision': 'old'}));
    await cubit.submit();
    expect(repository.initialized, 0);
    expect(repository.creates, 0);
    expect(cubit.state.createdDraft, isNull);
    expect(cubit.state.startSettings.manual, isFalse);
    expect(cubit.state.startSettings.source!['form'], 'leave');
    expect(cubit.state.message, contains('نسخهٔ فرم'));
  });
  test('a pending placeholder Manual is not a deliberate manual start selection', () {
    final settings = WorkflowStartSettings.fromDesign(WorkflowDesign(workflow: definition, stages: const [
      WorkflowStage(id: 'start', key: 'start', type: WorkflowStageType.start, title: 'شروع', sequence: 0,
        configurationComplete: false, config: {'trigger_type': 'Manual', 'initiator_roles': []})], transitions: const []));
    expect(settings.manual, isFalse);
    expect(settings.source, isNull);
  });
  testWidgets('a pending manual start cannot be dismissed or submitted twice',
      (tester) async {
    final client = Client()..hold = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home:
            WorkflowManualStartDialog(definition: 'created', client: client)));
    await tester.enterText(find.byType(TextField).first, 'بررسی امروز');
    await tester.enterText(find.byType(TextField).last, 'بازبینی درخواست');
    await tester.tap(find.text('شروع گردش کار'));
    await tester.pump();
    expect(client.calls, 1);
    expect(
        find.byWidgetPredicate(
            (widget) => widget is PopScope && !widget.canPop),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    client.hold!.complete();
    await tester.pumpAndSettle();
    expect(client.calls, 1);
  });

  test('form start requires a published identity before creating any draft',
      () async {
    final repository = Repository();
    final cubit = WorkflowFormCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('درخواست جدید');
    await cubit.submit();
    expect(cubit.state.message, contains('منتشرشده'));
    expect(repository.creates, 0);
  });

  test(
      'a failed second save retries the same draft and never reports fake success',
      () async {
    final repository = Repository()..failFirst = true;
    final cubit = WorkflowFormCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('درخواست جدید');
    cubit.changeStart(const WorkflowStartSettings(manual: true));
    await cubit.submit();
    expect(cubit.state.status, WorkflowFormStatus.failure);
    expect(repository.creates, 1);
    await cubit.submit();
    expect(cubit.state.status, WorkflowFormStatus.success);
    expect(repository.creates, 1);
    expect(repository.saves, 2);
    expect(repository.saved!.manual, isTrue);
  });

  test('editing Start reloads its real settings without creating another draft',
      () async {
    final repository = Repository();
    final cubit =
        WorkflowFormCubit(repository: repository, existing: definition);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.startSettings.manual, isTrue);
    await cubit.submit();
    expect(repository.creates, 0);
    expect(repository.saves, 1);
  });

  test(
      'form selection configures the same new Start with the selected published identity',
      () async {
    final repository = Repository();
    final cubit = WorkflowFormCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('درخواست جدید');
    cubit.changeStart(const WorkflowStartSettings(source: {
      'form': 'form',
      'revision': 'revision',
      'title': 'فرم واقعی'
    }));
    await cubit.submit();
    expect(cubit.state.status, WorkflowFormStatus.success);
    expect(repository.saved!.toMap()['submission_source'],
        {'form': 'form', 'revision': 'revision'});
  });

  testWidgets(
      'an unknown start response never retries or reports a successful run',
      (tester) async {
    final client = Client()..protocolFailure = true;
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home:
            WorkflowManualStartDialog(definition: 'created', client: client)));
    await tester.enterText(find.byType(TextField).first, 'بررسی امروز');
    await tester.enterText(find.byType(TextField).last, 'بازبینی قرارداد');
    await tester.tap(find.text('شروع گردش کار'));
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    expect(find.textContaining('نتیجهٔ شروع هنوز مشخص نیست'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'شروع گردش کار'))
            .onPressed,
        isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'inline additional settings contain four sections and confirm an editable copy at $width RTL',
        (tester) async {
      tester.view.physicalSize = Size(width, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const original = WorkflowStartSettings(manual: true);
      WorkflowStartSettings? result;
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: Scaffold(body: SingleChildScrollView(child:
              WorkflowStartAdditionalFields(value: original, onConfirmed: (value) => result = value)))));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('۱. جلوگیری از شروع تکراری'), findsOneWidget);
      expect(find.text('۲. جلوگیری از شروع مجدد پس از خاتمه'), findsOneWidget);
      await tester.ensureVisible(
          find.byKey(const ValueKey('workflow-manager-restart')));
      await tester.tap(find.byKey(const ValueKey('workflow-manager-restart')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('۳. الزام ثبت علت شروع دستی'), 160,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('۳. الزام ثبت علت شروع دستی'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('۴. ثبت سوابق آغاز گردش کار'), 160,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('۴. ثبت سوابق آغاز گردش کار'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('تأیید تنظیمات اضافی'), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('تأیید تنظیمات اضافی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأیید تنظیمات اضافی').hitTestable());
      await tester.pumpAndSettle();
      expect(result!.allowManagerRestart, isTrue);
      expect(original.allowManagerRestart, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'manual run requires a fresh reason and calls the existing online API at $width RTL',
        (tester) async {
      tester.view.physicalSize = Size(width, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client();
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: WorkflowManualStartDialog(
              definition: 'created', client: client)));
      await tester.tap(find.text('شروع گردش کار'));
      await tester.pumpAndSettle();
      expect(client.calls, 0);
      await tester.enterText(find.byType(TextField).first, 'بررسی امروز');
      await tester.enterText(
          find.byType(TextField).last, 'لزوم بازبینی قرارداد');
      await tester.tap(find.text('شروع گردش کار'));
      await tester.pumpAndSettle();
      expect(client.calls, 1);
      expect(client.sent!['reason'], 'لزوم بازبینی قرارداد');
      expect(tester.takeException(), isNull);
    });
  }

  test('editing legacy workflow without start changes does not call configureStart',
      () async {
    final repository = LegacyRepository();
    final cubit =
        WorkflowFormCubit(repository: repository, existing: definition);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('عنوان جدید برای گردش کار قدیمی');
    await cubit.submit();
    expect(cubit.state.status, WorkflowFormStatus.success);
    expect(repository.saves, 0);
  });
}
