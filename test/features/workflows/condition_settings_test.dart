import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/workflows/data/workflow_condition_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_condition_test.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const stage = WorkflowStage(
    id: 'CONDITION',
    key: 'CONDITION',
    type: WorkflowStageType.condition,
    title: 'شرط و مسیر',
    sequence: 3,
    configurationComplete: true,
    config: {
      'source_kind': 'Form',
      'source_field': 'amount',
      'operator': 'Greater Than',
      'compare_value': '500'
    });

class Repository extends Fake implements WorkflowRepository {
  Repository({this.modern = false});
  final bool modern;
  String? before;
  Map<String, dynamic>? saved;
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
      {String? beforeStage}) async {
    before = beforeStage;
    if (modern) {
      return const [
        WorkflowFieldOption(name: 'amount', label: 'مبلغ درخواست', type: 'Number', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'reason', label: 'شرح درخواست', type: 'Text', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'date', label: 'تاریخ درخواست', type: 'Date', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'flag', label: 'تأیید داده', type: 'Boolean', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'tags', label: 'گزینه‌ها', type: 'MultiSelect', source: 'Original', conditionVersion: 2,
          choices: ['a', 'b'], choiceLabels: {'a': 'اول', 'b': 'دوم'}),
        WorkflowFieldOption(name: 'when', label: 'تاریخ و ساعت', type: 'DateTime', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'person', label: 'پرسنل', type: 'Text', source: 'Original', conditionVersion: 2,
          linkDoctype: 'Employee'),
        WorkflowFieldOption(name: 'decision', label: 'نتیجه اقدام', type: 'Select', source: 'Stage', sourceStage: 'TASK',
          stageTitle: 'بررسی قبلی', conditionVersion: 2, choices: ['done', 'blocked'], choiceLabels: {'done': 'انجام شد', 'blocked': 'متوقف'}),
        WorkflowFieldOption(name: 'started_by', label: 'ثبت‌کننده درخواست', type: 'Text', source: 'System', conditionVersion: 2),
      ];
    }
    return const [
      WorkflowFieldOption(name: 'amount', label: 'مبلغ سند', type: 'Currency'),
      WorkflowFieldOption(
          name: 'amount',
          label: 'مبلغ فرم درخواست',
          type: 'Currency',
          source: 'Form'),
    ];
  }

  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved = config;
    return const WorkflowDesign(
        workflow: WorkflowDefinition(
            id: 'WF',
            code: 'WF',
            title: 'گردش',
            targetDoctype: 'ASOUD Workflow Request',
            status: WorkflowDefinitionStatus.inactive,
            isLocked: false,
            version: 1,
            stepsCount: 1,
            modified: null),
        stages: [],
        transitions: []);
  }
}

/// A repository that also runs the server-side condition dry run, so the form
/// can be exercised end to end (including through the preview wrapper).
class DryRunRepository extends Fake
    implements WorkflowRepository, WorkflowConditionTestRepository {
  DryRunRepository({this.dryRun, this.dryRunError, this.employees = const []});
  final WorkflowConditionTestResult? dryRun;
  final Object? dryRunError;
  final List<WorkflowTargetOption> employees;
  Map<String, dynamic>? saved;
  Map<String, dynamic>? lastSamples;

  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
          {String? beforeStage}) async =>
      const [
        WorkflowFieldOption(
            name: 'amount',
            label: 'مبلغ درخواست',
            type: 'Number',
            source: 'Original',
            conditionVersion: 2),
        WorkflowFieldOption(
            name: 'reason',
            label: 'شرح درخواست',
            type: 'Text',
            source: 'Original',
            conditionVersion: 2),
        WorkflowFieldOption(
            name: 'assignee',
            label: 'مسئول',
            type: 'Text',
            source: 'Original',
            conditionVersion: 2,
            valueSource: 'employee'),
        WorkflowFieldOption(
            name: 'approver',
            label: 'تأییدکننده',
            type: 'Text',
            source: 'Original',
            conditionVersion: 2,
            valueSource: 'user'),
        WorkflowFieldOption(
            name: 'total',
            label: 'مبلغ کل',
            type: 'Number',
            source: 'Original',
            conditionVersion: 2,
            currency: 'ریال'),
      ];
  @override
  Future<WorkflowFormOptions> getFormOptions() async => WorkflowFormOptions(
          companies: const [],
          modules: const [],
          roles: const [],
          departments: const [
            WorkflowTargetOption(id: 'DEPT-1', label: 'واحد حسابداری')
          ],
          employees: employees);
  @override
  Future<WorkflowDesign> getDesign(
          String definition) async =>
      const WorkflowDesign(
          workflow: WorkflowDefinition(
              id: 'WF',
              code: 'WF',
              title: 'گردش',
              targetDoctype: 'ASOUD Workflow Request',
              status: WorkflowDefinitionStatus.inactive,
              isLocked: false,
              version: 1,
              stepsCount: 1,
              modified: null),
          stages: [],
          transitions: []);
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved = config;
    return const WorkflowDesign(
        workflow: WorkflowDefinition(
            id: 'WF',
            code: 'WF',
            title: 'گردش',
            targetDoctype: 'ASOUD Workflow Request',
            status: WorkflowDefinitionStatus.inactive,
            isLocked: false,
            version: 1,
            stepsCount: 1,
            modified: null),
        stages: [],
        transitions: []);
  }

  @override
  Future<WorkflowConditionTestResult> testWorkflowCondition(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config,
      required Map<String, dynamic> samples}) async {
    lastSamples = samples;
    if (dryRunError != null) throw dryRunError!;
    return dryRun ?? const WorkflowConditionTestResult(result: true, rows: []);
  }
}

/// A client that answers the condition-fields call but throws a fixed error
/// for every other method, to simulate an older server.
class _OldServerClient extends Fake implements FrappeApiClient {
  _OldServerClient(this.otherError);
  final Object otherError;
  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.workflow.workflow_condition_fields') {
      return {
        'condition_fields_v2': [
          {
            'source_field': 'amount',
            'label': 'مبلغ درخواست',
            'field_type': 'Number',
            'source_kind': 'Original',
            'source_stage': '',
            'stage_title': '',
            'options': <String>[],
            'option_labels': <String, String>{},
          },
        ],
        'fields': <Map<String, dynamic>>[],
      };
    }
    throw otherError;
  }
}

class ConditionClient extends Fake implements FrappeApiClient {
  Map<String, dynamic>? sent;
  bool fail = false;
  @override
  Future<dynamic> callAsoudMethod(String method, {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.workflow.workflow_condition_fields');
    expect(data!['value_field'], 'person');
    return {'value_options': [{'value': 'EMP-1', 'label': 'علی محمدی'}]};
  }
  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.workflow.test_workflow_condition');
    sent = data;
    if (fail) throw StateError('sample-service-unavailable');
    final sample = (data!['samples'] as Map)['date'];
    return {'message': {'ok': true, 'data': {'result': sample == '2026-11-19',
      'rows': [{'id': 'date', 'result': sample == '2026-11-19', 'error': null}]}}};
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.evaluate().isEmpty && i < 25; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Boolean MultiSelect DateTime and reference values use typed existing controls and persist ids', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [
      {'id': 'flag', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'flag', 'field_type': 'Boolean', 'operator': 'Equals', 'value': 'false'},
      {'id': 'tags', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'tags', 'field_type': 'MultiSelect', 'operator': 'Contains', 'value': 'a'},
      {'id': 'when', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'when', 'field_type': 'DateTime', 'operator': 'Equals', 'value': '2026-11-19T09:30:00'},
      {'id': 'person', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'person', 'field_type': 'Text', 'operator': 'Equals', 'value': ''},
    ]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured,
        roles: const [], conditionRepository: WorkflowConditionRepository(ConditionClient())))));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('condition-value-flag')));
    await tap(tester, find.byKey(const ValueKey('option-true')));
    await tap(tester, find.byKey(const ValueKey('condition-value-tags')));
    await tap(tester, find.byKey(const ValueKey('option-b')));
    await tap(tester, find.byKey(const ValueKey('condition-value-person')));
    await tap(tester, find.text('علی محمدی'));
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rules = repository.saved!['conditions'] as List;
    expect(rules[0]['value'], 'true');
    expect(rules[1]['value'], 'b');
    expect(rules[2]['value'], '2026-11-19T09:30:00');
    expect(rules[3]['value'], 'EMP-1');
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('condition sample date uses the existing endpoint and keeps inputs after a failure at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = WorkflowDesignerCubit(repository: Repository(modern: true), definition: 'WF');
      addTearDown(cubit.close);
      final client = ConditionClient();
      final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
        'id': 'date', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'date',
        'field_type': 'Date', 'operator': 'Between', 'value': '2026-11-18', 'value_to': '2026-11-21'}]});
      await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured,
          roles: const [], conditionRepository: WorkflowConditionRepository(client)))));
      await tester.pumpAndSettle();
      await tap(tester, find.text('آزمایش تنظیمات شرط'));
      final sample = find.byKey(const ValueKey('condition-sample-date'));
      for (final value in ['2026-11-10', '2026-11-19']) {
        await tester.ensureVisible(sample);
        tester.widget<AppSelectField>(sample).onChanged!(value);
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('condition-run-test')));
        expect(client.sent!['samples'], {'date': value});
        expect(find.text(value == '2026-11-19' ? 'شرط برقرار است — خروجی اول' : 'شرط برقرار نیست — خروجی دوم'), findsOneWidget);
      }
      expect(JalaliDate.fromDateTime(DateTime(2026, 11, 19)).format(), '1405/08/28');
      client.fail = true;
      await tap(tester, find.byKey(const ValueKey('condition-run-test')));
      expect(find.byKey(const ValueKey('condition-test-result')), findsNothing);
      expect(tester.widget<AppSelectField>(sample).value, '2026-11-19');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid date range is shown inside its own card and clears after correction', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
      'id': 'range', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'date',
      'field_type': 'Date', 'operator': 'Between', 'value': '2026-11-21', 'value_to': '2026-11-18'}]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final card = find.byKey(const ValueKey('condition-row-range'));
    expect(find.descendant(of: card, matching: find.text('تاریخ شروع نباید بعد از تاریخ پایان باشد.')), findsOneWidget);
    tester.widget<AppSelectField>(find.byKey(const ValueKey('condition-end-range'))).onChanged!('2026-11-22');
    await tester.pumpAndSettle();
    expect(find.text('تاریخ شروع نباید بعد از تاریخ پایان باشد.'), findsNothing);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    expect(repository.saved, isNotNull);
  });
  testWidgets('condition reference layout in RTL with real fonts', (tester) async {
    await (FontLoader('Vazirmatn')..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = WorkflowDesignerCubit(
        repository: Repository(modern: true), definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'amount',
          'source_kind': 'Original',
          'source_stage': '',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Greater Than',
          'value': '50000000',
        }
      ]
    });
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: RepaintBoundary(
            key: const ValueKey('condition-capture'),
            child: BlocProvider.value(
                value: cubit,
                child: WorkflowStageSettingsPage(
                    stage: configured, roles: const [])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('۵۰۰۰۰۰۰۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_CONDITION')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('condition-capture')));
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('build/condition-reference.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
  testWidgets('condition rejects an overflowing calendar date', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit =
        WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'date',
          'source_kind': 'Original',
          'source_stage': '',
          'source_field': 'date',
          'field_type': 'Date',
          'operator': 'Equals',
          'value': '2025-02-31',
        }
      ]
    });
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: BlocProvider.value(
            value: cubit,
            child: WorkflowStageSettingsPage(
                stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأیید تنظیمات شرط و مسیر'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.textContaining('تاریخ معتبر نیست.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'condition v2 deletes the chosen row and saves OR without route data at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = Repository(modern: true);
      final cubit =
          WorkflowDesignerCubit(repository: repository, definition: 'WF');
      addTearDown(cubit.close);
      final configured = stage.copyWith(config: {
        'condition_version': 2,
        'combine': 'All',
        'conditions': [
          for (final id in ['one', 'two', 'three'])
            {
              'id': id,
              'source_kind': 'Original',
              'source_field': 'amount',
              'source_stage': '',
              'field_type': 'Number',
              'operator': 'Between',
              'value': '10',
              'value_to': '20',
            }
        ]
      });
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: BlocProvider.value(
              value: cubit,
              child: WorkflowStageSettingsPage(
                  stage: configured, roles: const []))));
      await tester.pumpAndSettle();
      expect(find.text('۱. تعریف شروط'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('condition-remove-two')));
      expect(find.byKey(const ValueKey('condition-row-two')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('condition-combine-Any')));
      await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
      expect(repository.saved!['condition_version'], 2);
      expect(repository.saved!['combine'], 'Any');
      final rows = repository.saved!['conditions'] as List;
      expect(rows.map((row) => row['id']), ['one', 'three']);
      expect(rows.first['value_to'], '20');
      expect(repository.saved!.containsKey('routes'), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'condition v2 exact range validation never saves reversed decimals',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit =
        WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'range',
          'source_kind': 'Original',
          'source_stage': '',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Between',
          'value': '0.100000000000000003',
          'value_to': '0.100000000000000001',
        }
      ]
    });
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: BlocProvider.value(
            value: cubit,
            child: WorkflowStageSettingsPage(
                stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    expect(find.text('۲. ترکیب شروط'), findsNothing);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    expect(repository.saved, isNull);
    expect(find.textContaining('ابتدای بازه از انتهای آن بزرگ‌تر است.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition v2 six rows are supported and Is Empty omits values',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit =
        WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        for (var i = 0; i < 6; i++)
          {
            'id': 'row$i',
            'source_kind': 'Original',
            'source_stage': '',
            'source_field': 'reason',
            'field_type': 'Text',
            'operator': 'Is Empty',
            'value': 'must not persist'
          },
      ]
    });
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: BlocProvider.value(
            value: cubit,
            child: WorkflowStageSettingsPage(
                stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('condition-value-row0')), findsNothing);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rules = repository.saved!['conditions'] as List;
    expect(rules, hasLength(6));
    expect(
        rules.any(
            (row) => row.containsKey('value') || row.containsKey('value_to')),
        isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'condition source change clears stale values and binds the selected prior action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit =
        WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'bind',
          'source_kind': 'Original',
          'source_stage': '',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Between',
          'value': '10',
          'value_to': '20',
        }
      ]
    });
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: BlocProvider.value(
            value: cubit,
            child: WorkflowStageSettingsPage(
                stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('condition-source-bind')));
    await tap(tester, find.byKey(const ValueKey('option-Stage')));
    expect(find.byKey(const ValueKey('condition-value-bind')), findsNothing);
    await tap(tester, find.byKey(const ValueKey('condition-previous-bind')));
    await tap(tester, find.byKey(const ValueKey('option-TASK')));
    await tap(tester, find.byKey(const ValueKey('condition-field-bind')));
    await tap(tester, find.byKey(const ValueKey('option-decision')));
    await tap(tester, find.byKey(const ValueKey('condition-value-bind')));
    await tap(tester, find.byKey(const ValueKey('option-done')));
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rule = (repository.saved!['conditions'] as List).single;
    expect(rule['source_kind'], 'Stage');
    expect(rule['source_stage'], 'TASK');
    expect(rule['source_field'], 'decision');
    expect(rule['operator'], 'Equals');
    expect(rule['value'], 'done');
    expect(rule.containsKey('value_to'), isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'condition keeps the actual Form source when document has same field at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = Repository();
      final cubit =
          WorkflowDesignerCubit(repository: repository, definition: 'WF');
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: BlocProvider.value(
              value: cubit,
              child:
                  const WorkflowStageSettingsPage(stage: stage, roles: []))));
      await tester.pumpAndSettle();
      expect(repository.before, 'CONDITION');
      expect(find.text('مبلغ فرم درخواست'), findsOneWidget);
      await tester.tap(find.text('ذخیره مرحله'));
      await tester.pumpAndSettle();
      expect(repository.saved!['source_kind'], 'Form');
      expect(repository.saved!['source_field'], 'amount');
      expect(repository.saved!['compare_value'], '500');
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> pumpCondition(WidgetTester tester, WorkflowRepository repository,
      {WorkflowStage? stageOverride,
      double width = 390,
      bool load = false}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit =
        WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    if (load) await cubit.load();
    final target = stageOverride ?? stage;
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: BlocProvider.value(
            value: cubit,
            child: WorkflowStageSettingsPage(stage: target, roles: const []))));
    await tester.pumpAndSettle();
  }

  testWidgets('condition with one row numbers outputs and test as 2 and 3',
      (tester) async {
    await pumpCondition(tester, DryRunRepository());
    expect(find.text('۱. تعریف شروط'), findsOneWidget);
    expect(find.text('۲. ترکیب شروط'), findsNothing);
    expect(find.text('۲. خروجی‌های شرط'), findsOneWidget);
    expect(find.text('۳. آزمایش شرط'), findsOneWidget);
    expect(find.text('تأیید تنظیمات شرط و مسیر'), findsOneWidget);
    expect(
        find.text(
            'اتصال خروجی‌ها به مراحل بعدی فقط در صفحه طراحی گردش کار انجام می‌شود.'),
        findsOneWidget);
    expect(find.text('خروجی اول'), findsOneWidget);
    expect(find.text('خروجی دوم'), findsOneWidget);
    expect(find.textContaining('· True'), findsNothing);
    expect(find.textContaining('· False'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'condition with two rows numbers combine, outputs and test as 2, 3, 4',
      (tester) async {
    final two = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'a',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1'
        },
        {
          'id': 'b',
          'source_kind': 'Original',
          'source_field': 'reason',
          'field_type': 'Text',
          'operator': 'Equals',
          'value': 'x'
        },
      ]
    });
    await pumpCondition(tester, DryRunRepository(), stageOverride: two);
    expect(find.text('۲. ترکیب شروط'), findsOneWidget);
    expect(find.text('۳. خروجی‌های شرط'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('۴. آزمایش شرط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition source and field change reset the dependent values',
      (tester) async {
    final repository = DryRunRepository();
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Between',
          'value': '10',
          'value_to': '20',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    // Change the field: operator resets to Equals and the value clears.
    await tap(tester, find.byKey(const ValueKey('condition-field-r')));
    await tap(tester, find.byKey(const ValueKey('option-reason')));
    expect(find.byKey(const ValueKey('condition-value-r')), findsOneWidget);
    expect(find.byKey(const ValueKey('condition-end-r')), findsNothing);
    // Change the source: the field and value clear.
    await tap(tester, find.byKey(const ValueKey('condition-source-r')));
    await tap(tester, find.byKey(const ValueKey('option-System')));
    expect(find.byKey(const ValueKey('condition-value-r')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition empty operator hides the value input', (tester) async {
    final repository = DryRunRepository();
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'reason',
          'field_type': 'Text',
          'operator': 'Is Empty',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    expect(find.byKey(const ValueKey('condition-value-r')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition between range rejects a reversed start',
      (tester) async {
    final repository = DryRunRepository();
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Between',
          'value': '20',
          'value_to': '10',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    expect(repository.saved, isNull);
    expect(find.textContaining('ابتدای بازه از انتهای آن بزرگ‌تر است.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition whitespace-only text value is rejected',
      (tester) async {
    final repository = DryRunRepository();
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'reason',
          'field_type': 'Text',
          'operator': 'Equals',
          'value': '   ',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    expect(repository.saved, isNull);
    expect(find.textContaining('مقدار مقایسه وارد نشده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'condition employee value source stores the id and shows the name',
      (tester) async {
    final repository = DryRunRepository(employees: const [
      WorkflowTargetOption(id: 'EMP-1', label: 'احمد رضایی'),
    ]);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'assignee',
          'field_type': 'Text',
          'operator': 'Equals',
        }
      ]
    });
    await pumpCondition(tester, repository,
        stageOverride: configured, load: true);
    await tap(tester, find.byKey(const ValueKey('condition-value-r')));
    await tap(tester, find.byKey(const ValueKey('option-EMP-1')));
    expect(find.text('احمد رضایی'), findsOneWidget);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rule = (repository.saved!['conditions'] as List).single;
    expect(rule['value'], 'EMP-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition currency label is shown next to the amount input',
      (tester) async {
    final repository = DryRunRepository();
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'total',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '5',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    expect(find.text('ریال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run shows the server result and row errors',
      (tester) async {
    final repository = DryRunRepository(
        dryRun: const WorkflowConditionTestResult(result: true, rows: [
      WorkflowConditionTestRow(id: 'r', result: true),
      WorkflowConditionTestRow(
          id: 'bad', result: false, error: 'مقدار نمونه معتبر نیست.'),
    ]));
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1'
        },
        {
          'id': 'bad',
          'source_kind': 'Original',
          'source_field': 'reason',
          'field_type': 'Text',
          'operator': 'Equals',
          'value': 'x'
        },
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('شرط برقرار است — خروجی اول'), findsOneWidget);
    expect(find.textContaining('مقدار نمونه معتبر نیست.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run through the preview wrapper shows the result',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final inner = DryRunRepository(
        dryRun: const WorkflowConditionTestResult(result: false, rows: []));
    final repository = PreviewFallbackWorkflowRepository(inner);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('شرط برقرار نیست — خروجی دوم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run falls back on an unsupported server',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // The wrapper delegates to the inner repository, so to exercise the
    // unsupported path we wrap a repository that does not implement the
    // interface.
    final unsupported = PreviewFallbackWorkflowRepository(_PlainRepository());
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, unsupported, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.textContaining('سرور فعلی از آزمایش شرط پشتیبانی نمی‌کند'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run shows a forbidden message', (tester) async {
    final repository = DryRunRepository(
        dryRunError:
            const ApiException(kind: ApiFailureKind.forbidden, message: 'no'));
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('دسترسی لازم برای آزمایش شرط را ندارید.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run shows a network error message',
      (tester) async {
    final repository = DryRunRepository(
        dryRunError: const ApiException(
            kind: ApiFailureKind.network,
            message: 'ارتباط با سرور برقرار نشد.'));
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('ارتباط با سرور برقرار نشد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'condition dry run on an older server shows the unsupported message',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final client = _OldServerClient(const ApiException(
        kind: ApiFailureKind.validation,
        statusCode: 417,
        message:
            'Failed to get method for command asoud_erp.api.v1.workflow.test_workflow_condition with module has no attribute'));
    final repository = FrappeWorkflowRepository(client);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.textContaining('سرور فعلی از آزمایش شرط پشتیبانی نمی‌کند'),
        findsOneWidget);
    expect(find.textContaining('Failed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run shows a Persian validation message as is',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final client = _OldServerClient(const ApiException(
        kind: ApiFailureKind.validation,
        statusCode: 417,
        message: 'مقدار نمونه معتبر نیست.'));
    final repository = FrappeWorkflowRepository(client);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('مقدار نمونه معتبر نیست.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition dry run result clears when the config changes',
      (tester) async {
    final repository = DryRunRepository(
        dryRun: const WorkflowConditionTestResult(result: true, rows: []));
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'amount',
          'field_type': 'Number',
          'operator': 'Equals',
          'value': '1',
        }
      ]
    });
    await pumpCondition(tester, repository, stageOverride: configured);
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(find.text('شرط برقرار است — خروجی اول'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('condition-value-r')), '2');
    await tester.pumpAndSettle();
    expect(find.text('شرط برقرار است — خروجی اول'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition user value source stores the user id', (tester) async {
    final repository = DryRunRepository(employees: const [
      WorkflowTargetOption(
          id: 'EMP-1', label: 'احمد رضایی', userId: 'ahmad@example.com'),
    ]);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'approver',
          'field_type': 'Text',
          'operator': 'Equals',
        }
      ]
    });
    await pumpCondition(tester, repository,
        stageOverride: configured, load: true);
    await tap(tester, find.byKey(const ValueKey('condition-value-r')));
    expect(find.text('انتخاب کاربر'), findsOneWidget);
    await tap(tester, find.text('احمد رضایی'));
    await tap(tester, find.widgetWithText(FilledButton, 'تأیید انتخاب'));
    await tester.pumpAndSettle();
    expect(find.text('احمد رضایی'), findsOneWidget);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rule = (repository.saved!['conditions'] as List).single;
    expect(rule['value'], 'ahmad@example.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition employee sample uses the reference picker',
      (tester) async {
    final repository = DryRunRepository(employees: const [
      WorkflowTargetOption(id: 'EMP-1', label: 'احمد رضایی'),
    ]);
    final configured = stage.copyWith(config: {
      'condition_version': 2,
      'combine': 'All',
      'conditions': [
        {
          'id': 'r',
          'source_kind': 'Original',
          'source_field': 'assignee',
          'field_type': 'Text',
          'operator': 'Equals',
        }
      ]
    });
    await pumpCondition(tester, repository,
        stageOverride: configured, load: true);
    await tap(tester, find.byKey(const ValueKey('condition-value-r')));
    await tap(tester, find.byKey(const ValueKey('option-EMP-1')));
    await tap(tester, find.byKey(const ValueKey('condition-sample-r')));
    await tap(tester, find.byKey(const ValueKey('option-EMP-1')));
    await tap(tester, find.text('اجرای آزمایشی'));
    expect(repository.lastSamples!['r'], 'EMP-1');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('condition form has no overflow at $width', (tester) async {
      final repository = DryRunRepository();
      final configured = stage.copyWith(config: {
        'condition_version': 2,
        'combine': 'All',
        'conditions': [
          {
            'id': 'a',
            'source_kind': 'Original',
            'source_field': 'amount',
            'field_type': 'Number',
            'operator': 'Between',
            'value': '1',
            'value_to': '2'
          },
          {
            'id': 'b',
            'source_kind': 'Original',
            'source_field': 'reason',
            'field_type': 'Text',
            'operator': 'Equals',
            'value': 'x'
          },
        ]
      });
      await pumpCondition(tester, repository,
          stageOverride: configured, width: width);
      expect(find.text('۲. ترکیب شروط'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Overflow would surface as a RenderFlex exception during build.
      expect(tester.takeException(), isNull);
    });
  }
}

/// A repository without the dry-run interface, to exercise the unsupported path.
class _PlainRepository extends Fake implements WorkflowRepository {
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
          {String? beforeStage}) async =>
      const [
        WorkflowFieldOption(
            name: 'amount',
            label: 'مبلغ درخواست',
            type: 'Number',
            source: 'Original',
            conditionVersion: 2),
      ];
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: [], modules: [], roles: []);
  @override
  Future<WorkflowDesign> getDesign(
          String definition) async =>
      const WorkflowDesign(
          workflow: WorkflowDefinition(
              id: 'WF',
              code: 'WF',
              title: 'گردش',
              targetDoctype: 'ASOUD Workflow Request',
              status: WorkflowDefinitionStatus.inactive,
              isLocked: false,
              version: 1,
              stepsCount: 1,
              modified: null),
          stages: [],
          transitions: []);
  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) async =>
      const WorkflowDesign(
          workflow: WorkflowDefinition(
              id: 'WF',
              code: 'WF',
              title: 'گردش',
              targetDoctype: 'ASOUD Workflow Request',
              status: WorkflowDefinitionStatus.inactive,
              isLocked: false,
              version: 1,
              stepsCount: 1,
              modified: null),
          stages: [],
          transitions: []);
}
