import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const stage = WorkflowStage(id: 'CONDITION', key: 'CONDITION', type: WorkflowStageType.condition,
  title: 'شرط و مسیر', sequence: 3, configurationComplete: true,
  config: {'source_kind': 'Form', 'source_field': 'amount', 'operator': 'Greater Than', 'compare_value': '500'});

class Repository extends Fake implements WorkflowRepository {
  Repository({this.modern = false});
  final bool modern;
  String? before;
  Map<String, dynamic>? saved;
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition, {String? beforeStage}) async {
    before = beforeStage;
    if (modern) {
      return const [
        WorkflowFieldOption(name: 'amount', label: 'مبلغ درخواست', type: 'Number', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'reason', label: 'شرح درخواست', type: 'Text', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'date', label: 'تاریخ درخواست', type: 'Date', source: 'Original', conditionVersion: 2),
        WorkflowFieldOption(name: 'decision', label: 'نتیجه اقدام', type: 'Select', source: 'Stage', sourceStage: 'TASK',
          stageTitle: 'بررسی قبلی', conditionVersion: 2, choices: ['done', 'blocked'], choiceLabels: {'done': 'انجام شد', 'blocked': 'متوقف'}),
        WorkflowFieldOption(name: 'started_by', label: 'ثبت‌کننده درخواست', type: 'Text', source: 'System', conditionVersion: 2),
      ];
    }
    return const [
      WorkflowFieldOption(name: 'amount', label: 'مبلغ سند', type: 'Currency'),
      WorkflowFieldOption(name: 'amount', label: 'مبلغ فرم درخواست', type: 'Currency', source: 'Form'),
    ];
  }
  @override
  Future<WorkflowDesign> saveStageSettings({required String definition, required String stage,
      required Map<String, dynamic> config}) async {
    saved = config;
    return const WorkflowDesign(workflow: WorkflowDefinition(id: 'WF', code: 'WF',
      title: 'گردش', targetDoctype: 'ASOUD Workflow Request', status: WorkflowDefinitionStatus.inactive,
      isLocked: false, version: 1, stepsCount: 1, modified: null), stages: [], transitions: []);
  }
}

void main() {
  testWidgets('condition reference layout in RTL with real fonts', (tester) async {
    await (FontLoader('Vazirmatn')..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = WorkflowDesignerCubit(repository: Repository(modern: true), definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
      'id': 'amount', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'amount',
      'field_type': 'Number', 'operator': 'Greater Than', 'value': '50000000',
    }]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: RepaintBoundary(key: const ValueKey('condition-capture'), child: BlocProvider.value(
        value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const [])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('۵۰۰۰۰۰۰۰'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_CONDITION')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('condition-capture')));
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('build/condition-reference.png').writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
  testWidgets('condition rejects an overflowing calendar date', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
      'id': 'date', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'date',
      'field_type': 'Date', 'operator': 'Equals', 'value': '2025-02-31',
    }]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأیید تنظیمات شرط و مسیر'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.textContaining('تاریخ معتبر نیست.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('condition v2 deletes the chosen row and saves OR without route data at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = Repository(modern: true);
      final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
      addTearDown(cubit.close);
      final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All',
        'conditions': [for (final id in ['one', 'two', 'three']) {
          'id': id, 'source_kind': 'Original', 'source_field': 'amount',
          'source_stage': '', 'field_type': 'Number', 'operator': 'Between', 'value': '10', 'value_to': '20',
        }]});
      await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
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
  testWidgets('condition v2 exact range validation never saves reversed decimals', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
      'id': 'range', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'amount', 'field_type': 'Number',
      'operator': 'Between', 'value': '0.100000000000000003', 'value_to': '0.100000000000000001',
    }]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    expect(find.text('۲. ترکیب شروط'), findsNothing);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    expect(repository.saved, isNull);
    expect(find.textContaining('ابتدای بازه از انتهای آن بزرگ‌تر است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('condition v2 six rows are supported and Is Empty omits values', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [
      for (var i = 0; i < 6; i++) {'id': 'row$i', 'source_kind': 'Original', 'source_stage': '',
        'source_field': 'reason', 'field_type': 'Text', 'operator': 'Is Empty', 'value': 'must not persist'},
    ]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('condition-value-row0')), findsNothing);
    await tap(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    final rules = repository.saved!['conditions'] as List;
    expect(rules, hasLength(6));
    expect(rules.any((row) => row.containsKey('value') || row.containsKey('value_to')), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('condition source change clears stale values and binds the selected prior action', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = Repository(modern: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
    addTearDown(cubit.close);
    final configured = stage.copyWith(config: {'condition_version': 2, 'combine': 'All', 'conditions': [{
      'id': 'bind', 'source_kind': 'Original', 'source_stage': '', 'source_field': 'amount', 'field_type': 'Number',
      'operator': 'Between', 'value': '10', 'value_to': '20',
    }]});
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      home: BlocProvider.value(value: cubit, child: WorkflowStageSettingsPage(stage: configured, roles: const []))));
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
    testWidgets('condition keeps the actual Form source when document has same field at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = Repository();
      final cubit = WorkflowDesignerCubit(repository: repository, definition: 'WF');
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: BlocProvider.value(value: cubit,
          child: const WorkflowStageSettingsPage(stage: stage, roles: []))));
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
}

