import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_graph_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stage = WorkflowStage(
    id: 'stg-1',
    key: 'start',
    title: 'مرحله آغاز',
    sequence: 0,
    type: WorkflowStageType.start,
    configurationComplete: true,
    positionX: 0,
    positionY: 0,
  );
  final design = WorkflowDesign(
    workflow: WorkflowDefinition(
      id: 'wf-1',
      code: 'WF-1',
      title: 'گردش کار تست',
      targetDoctype: 'Test',
      status: WorkflowDefinitionStatus.active,
      isLocked: false,
      version: 1,
      stepsCount: 1,
      modified: DateTime(2026, 10, 10),
    ),
    stages: const [stage],
    transitions: const [],
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('workflow graph fits the viewport at $width', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 600,
              child: WorkflowGraphCanvas(
                design: design,
                onOpenStage: (_) {},
                onMoveStage: (_, __, ___) {},
                onMoveEnd: () {},
                onInsertOnTransition: (_) {},
                onCreateTransition: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final node = find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 190 && w.height == 118);
      expect(node, findsOneWidget);
      final nodeRect = tester.getRect(node);
      expect(nodeRect.left, greaterThanOrEqualTo(0));
      expect(nodeRect.right, lessThanOrEqualTo(width + 0.5));

      final content = find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 760);
      expect(tester.getRect(content).right, lessThanOrEqualTo(width + 0.5));
      expect(tester.takeException(), isNull);
    });
  }
}