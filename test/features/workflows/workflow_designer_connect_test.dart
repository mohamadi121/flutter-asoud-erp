import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _designId = 'WF-CONN-1';

WorkflowDesign _design() => WorkflowDesign(
      workflow: const WorkflowDefinition(
        id: _designId,
        code: 'CONN-1',
        title: 'گردش اتصال',
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
            id: 'task',
            key: 'task',
            type: WorkflowStageType.userTask,
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
      transitions: const [
        WorkflowTransition(id: 'r1', fromStage: 'start', toStage: 'task', label: ''),
        WorkflowTransition(id: 'r2', fromStage: 'task', toStage: 'end', label: ''),
      ],
    );

class _Repository extends Fake implements WorkflowRepository {
  ({String from, String to, String action})? connected;
  @override
  Future<WorkflowDesign> getDesign(String definition) async => _design();
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
    connected = (from: fromStage, to: toStage, action: action);
    return _design();
  }
}

void main() {
  testWidgets('dragging a node onto another saves a new route through connectStages',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    await tester.pumpWidget(
        RepositoryProvider<WorkflowRepository>.value(
            value: repository,
            child: MaterialApp(
                theme: AsoudTheme.light,
                builder: (_, child) => Directionality(
                    textDirection: TextDirection.rtl, child: child!),
                home: WorkflowDesignerPage(definition: _designId))));
    await tester.pumpAndSettle();

    // Drag from the 'task' node handle onto the 'end' node.
    final handle = find.byKey(const ValueKey('workflow-connect-handle-task'));
    expect(handle, findsOneWidget);
    final targetCenter = tester.getCenter(find.text('پایان'));
    final start = tester.getCenter(handle);
    await tester.timedDrag(
        handle, targetCenter - start, const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The route-name dialog appears.
    expect(find.text('اتصال دو مرحله'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ادامه فرایند');
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();

    expect(repository.connected, isNotNull);
    expect(repository.connected!.from, 'task');
    expect(repository.connected!.to, 'end');
    expect(repository.connected!.action, 'ادامه فرایند');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty route name is rejected with a Persian message',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    await tester.pumpWidget(
        RepositoryProvider<WorkflowRepository>.value(
            value: repository,
            child: MaterialApp(
                theme: AsoudTheme.light,
                builder: (_, child) => Directionality(
                    textDirection: TextDirection.rtl, child: child!),
                home: WorkflowDesignerPage(definition: _designId))));
    await tester.pumpAndSettle();

    final handle = find.byKey(const ValueKey('workflow-connect-handle-task'));
    final targetCenter = tester.getCenter(find.text('پایان'));
    final start = tester.getCenter(handle);
    await tester.timedDrag(
        handle, targetCenter - start, const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Confirm with an empty name.
    await tester.tap(find.text('ایجاد مسیر'));
    await tester.pumpAndSettle();
    expect(find.text('نام مسیر را وارد کنید.'), findsOneWidget);
    expect(repository.connected, isNull);
    expect(tester.takeException(), isNull);
  });
}
