import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _designId = 'WF-COND-1';

WorkflowDesign _design({List<WorkflowTransition> fromCondition = const []}) =>
    WorkflowDesign(
      workflow: const WorkflowDefinition(
        id: _designId,
        code: 'COND-1',
        title: 'گردش شرط',
        targetDoctype: 'ASOUD Workflow Request',
        status: WorkflowDefinitionStatus.inactive,
        isLocked: false,
        version: 1,
        stepsCount: 3,
        modified: null,
      ),
      stages: const [
        WorkflowStage(
            id: 'start',
            key: 'start',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 0,
            configurationComplete: true,
            positionX: 30,
            positionY: 30),
        WorkflowStage(
            id: 'cond',
            key: 'cond',
            type: WorkflowStageType.condition,
            title: 'بررسی',
            sequence: 1,
            configurationComplete: true,
            positionX: 30,
            positionY: 300),
        WorkflowStage(
            id: 'end',
            key: 'end',
            type: WorkflowStageType.end,
            title: 'پایان',
            sequence: 2,
            configurationComplete: true,
            positionX: 30,
            positionY: 570),
      ],
      transitions: [
        const WorkflowTransition(id: 'r1', fromStage: 'start', toStage: 'cond', label: ''),
        ...fromCondition,
      ],
    );

class _Repository extends Fake implements WorkflowRepository {
  _Repository({this.design = _design, this.error});
  final WorkflowDesign Function() design;
  final ApiException? error;
  ({String from, String to, String action, Map<String, dynamic> condition})?
      connected;
  int calls = 0;

  @override
  Future<WorkflowDesign> getDesign(String definition) async => design();
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: ['دفتر نمونه'], modules: []);
  @override
  Future<WorkflowDesign> connectStages({
    required String definition,
    required String fromStage,
    required String toStage,
    required String action,
    Map<String, dynamic> condition = const {},
  }) async {
    calls++;
    if (error != null) throw error!;
    connected = (from: fromStage, to: toStage, action: action, condition: condition);
    return design();
  }
}

Future<void> _pump(WidgetTester tester, _Repository repository) async {
  await tester.pumpWidget(RepositoryProvider<WorkflowRepository>.value(
      value: repository,
      child: MaterialApp(
          theme: AsoudTheme.light,
          builder: (_, child) => Directionality(
              textDirection: TextDirection.rtl, child: child!),
          home: WorkflowDesignerPage(definition: _designId))));
  await tester.pumpAndSettle();
}

Future<void> _dragFromCondition(WidgetTester tester) async {
  final handle = find.byKey(const ValueKey('workflow-connect-handle-cond'));
  expect(handle, findsOneWidget);
  final targetCenter = tester.getCenter(find.text('پایان'));
  final start = tester.getCenter(handle);
  await tester.timedDrag(
      handle, targetCenter - start, const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

FilledButton _confirm(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'ایجاد مسیر'));

void main() {
  testWidgets('dragging from a Condition handle offers the yes output and sends result true',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    await _pump(tester, repository);
    await _dragFromCondition(tester);

    // The yes/no chooser replaces the free-text route dialog.
    expect(find.text('اتصال خروجی شرط'), findsOneWidget);
    expect(find.text('اتصال دو مرحله'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('شرط برقرار است'), findsOneWidget);
    expect(find.text('شرط برقرار نیست'), findsOneWidget);

    await tester.tap(find.text('شرط برقرار است'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(repository.connected, isNotNull);
    expect(repository.connected!.from, 'cond');
    expect(repository.connected!.to, 'end');
    expect(repository.connected!.condition, {'result': true});
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing the no output sends result false', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    await _pump(tester, repository);
    await _dragFromCondition(tester);

    await tester.tap(find.text('شرط برقرار نیست'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(repository.connected, isNotNull);
    expect(repository.connected!.condition, {'result': false});
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-used output is disabled and the free one still works',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(
        design: () => _design(fromCondition: const [
              WorkflowTransition(
                  id: 'r2',
                  fromStage: 'cond',
                  toStage: 'end',
                  label: 'شرط برقرار است',
                  condition: {'result': true}),
            ]));
    await _pump(tester, repository);
    await _dragFromCondition(tester);

    expect(
        find.text('این خروجی قبلا‌ً به یک مرحله متصل شده است.'), findsOneWidget);
    // The used output cannot be selected, so the confirm stays disabled.
    await tester.tap(find.text('شرط برقرار است'));
    await tester.pumpAndSettle();
    expect(_confirm(tester).onPressed, isNull);

    await tester.tap(find.text('شرط برقرار نیست'));
    await tester.pumpAndSettle();
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(repository.connected, isNotNull);
    expect(repository.connected!.condition, {'result': false});
    expect(tester.takeException(), isNull);
  });

  testWidgets('when both outputs are used the confirm is disabled and nothing is sent',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(
        design: () => _design(fromCondition: const [
              WorkflowTransition(
                  id: 'r2',
                  fromStage: 'cond',
                  toStage: 'end',
                  label: 'شرط برقرار است',
                  condition: {'result': true}),
              WorkflowTransition(
                  id: 'r3',
                  fromStage: 'cond',
                  toStage: 'end',
                  label: 'شرط برقرار نیست',
                  condition: {'result': false}),
            ]));
    await _pump(tester, repository);
    await _dragFromCondition(tester);

    expect(
        find.text('هر دو خروجی این شرط قبلا‌ً متصل شده‌اند؛ برای تغییر، مسیر موجود را حذف کنید.'),
        findsOneWidget);
    expect(_confirm(tester).onPressed, isNull);
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(repository.calls, 0);
    expect(repository.connected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a validation refusal shows the server sentence, not the generic one',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(
        error: const ApiException(
            kind: ApiFailureKind.validation,
            message: 'خروجی شرط باید برقرار یا برقرار نیست باشد.'));
    await _pump(tester, repository);
    await _dragFromCondition(tester);

    await tester.tap(find.text('شرط برقرار است'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(
        find.text('خروجی شرط باید برقرار یا برقرار نیست باشد.'), findsWidgets);
    expect(find.text('ایجاد مسیر ممکن نشد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the condition output dialog does not overflow at 320 and 390 px',
      (tester) async {
    for (final width in const [320, 390]) {
      tester.view.physicalSize = Size(width.toDouble(), 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      await _pump(tester, repository);
      await _dragFromCondition(tester);
      expect(find.text('اتصال خروجی شرط'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
    }
  });
}
