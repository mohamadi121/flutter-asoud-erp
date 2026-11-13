import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_end_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements WorkflowRepository {
  Map<String, dynamic>? saved;
  bool fail = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<WorkflowDesign> saveStageSettings({required String definition, required String stage,
      required Map<String, dynamic> config}) async {
    if (fail) throw StateError('save refused');
    saved = config;
    return const WorkflowDesign(workflow: WorkflowDefinition(id: 'wf', code: 'wf', title: 'گردش آزمایش',
      targetDoctype: 'ASOUD Workflow Request', status: WorkflowDefinitionStatus.inactive, isLocked: false,
      version: 1, stepsCount: 2, modified: null), stages: [], transitions: []);
  }
}

void main() {
  const outcomes = {'Completed': 'تکمیل موفق', 'Rejected': 'رد نهایی', 'Cancelled': 'لغو فرایند',
    'Stopped': 'توقف فرایند (بدون موفقیت)'};
  Future<_Repository> open(WidgetTester tester, {double width = 390, String outcome = 'Completed', bool fail = false}) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()..fail = fail;
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'wf');
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => BlocProvider.value(value: cubit,
          child: WorkflowEndSettingsPage(stage: WorkflowStage(id: 'end', key: 'end', type: WorkflowStageType.end,
            title: 'پایان فرایند', sequence: 2, configurationComplete: true,
            config: {'outcome': outcome, 'result_label': 'پیام قبلی'}))))), child: const Text('بازکردن'))))));
    await tester.tap(find.text('بازکردن'));
    await tester.pumpAndSettle();
    return repository;
  }

  for (final width in [320.0, 390.0, 430.0]) {
    for (final entry in outcomes.entries) {
      testWidgets('${entry.key} restores and saves without redesign or overflow at $width', (tester) async {
        final repository = await open(tester, width: width, outcome: entry.key);
        expect(find.text('پایان عملیات'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text(entry.value), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, 'پایان ویرایش‌شده');
        await tester.enterText(find.byType(TextFormField).last, 'پیام نتیجه جدید');
        await tester.tap(find.text('ذخیره تنظیمات پایان'));
        await tester.pumpAndSettle();
        expect(repository.saved, containsPair('outcome', entry.key));
        expect(repository.saved, containsPair('title', 'پایان ویرایش‌شده'));
        expect(repository.saved, containsPair('result_label', 'پیام نتیجه جدید'));
        expect(find.text('بازکردن'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('cancel does not save unconfirmed title or message', (tester) async {
    final repository = await open(tester);
    await tester.enterText(find.byType(TextFormField).first, 'تغییر تأییدنشده');
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.text('بازکردن'), findsOneWidget);
  });

  testWidgets('invalid saved result is not silently changed to success', (tester) async {
    final repository = await open(tester, outcome: 'Unknown');
    await tester.tap(find.text('ذخیره تنظیمات پایان'));
    await tester.pumpAndSettle();
    expect(find.text('نتیجه نهایی معتبر انتخاب کنید.'), findsOneWidget);
    expect(repository.saved, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رد نهایی').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره تنظیمات پایان'));
    await tester.pumpAndSettle();
    expect(repository.saved, containsPair('outcome', 'Rejected'));
  });

  testWidgets('save failure retains the form and inputs for correction', (tester) async {
    final repository = await open(tester, fail: true);
    await tester.tap(find.text('ذخیره تنظیمات پایان'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.text('پایان عملیات'), findsOneWidget);
    expect(find.text('پیام قبلی'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
