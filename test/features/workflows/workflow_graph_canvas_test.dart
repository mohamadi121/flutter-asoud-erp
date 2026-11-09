import 'dart:io';
import 'dart:ui' as ui;

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_graph_canvas.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_graph_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _workflow = WorkflowDefinition(
    id: 'saved',
    code: 'saved',
    title: 'فرایند ذخیره‌شده',
    targetDoctype: 'ASOUD Workflow Request',
    status: WorkflowDefinitionStatus.inactive,
    isLocked: false,
    version: 3,
    stepsCount: 7,
    modified: null);

WorkflowStage node(WorkflowStageType type,
        {String? title, double x = 30, double y = 30}) =>
    WorkflowStage(
        id: type.name,
        key: type.name,
        type: type,
        title: title ?? type.name,
        sequence: type.index,
        configurationComplete: true,
        positionX: x,
        positionY: y);

Widget app(WorkflowDesign design,
        {ValueChanged<WorkflowStage>? open,
        ValueChanged<WorkflowTransition>? insert,
        ValueChanged<WorkflowStage>? connect,
        void Function(String, double, double)? move,
        VoidCallback? moved}) =>
    MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AsoudTheme.light,
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
            body: WorkflowGraphCanvas(
                design: design,
                onOpenStage: open ?? (_) {},
                onMoveStage: move ?? (_, x, y) {},
                onMoveEnd: moved ?? () {},
                onInsertOnTransition: insert ?? (_) {},
                onCreateTransition: connect ?? (_) {})));

void main() {
  setUpAll(() async {
    await (FontLoader('Vazirmatn')
          ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('existing saved titles wrap instead of being limited to one line',
      (tester) async {
    final task = node(WorkflowStageType.userTask,
        title: 'بررسی اطلاعات درخواست خرید واحد بازرگانی');
    await tester.pumpWidget(app(WorkflowDesign(
        workflow: _workflow, stages: [task], transitions: const [])));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(task.title));
    expect(text.maxLines, isNot(1));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final type in WorkflowStageType.values) {
      testWidgets('$type remains tappable without overflow at $width RTL',
          (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = node(type, title: 'بررسی و ثبت اطلاعات درخواست');
        final design = WorkflowDesign(
            workflow: _workflow, stages: [saved], transitions: const []);
        WorkflowStage? opened, connected;
        await tester.pumpWidget(app(design,
            open: (stage) => opened = stage,
            connect: (stage) => connected = stage));
        await tester.pumpAndSettle();
        await tester.tap(find.text(saved.title));
        await tester.pumpAndSettle();
        expect(opened, same(saved));
        if (type != WorkflowStageType.end) {
          await tester.tap(find.byIcon(Icons.add_link_rounded));
          expect(connected, same(saved));
        }
        expect(design.stages.single, same(saved));
        expect(design.transitions, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'transition plus retains its edge, location and insertion callback',
      (tester) async {
    final start = node(WorkflowStageType.start, x: 30, y: 30);
    final end = node(WorkflowStageType.end, x: 30, y: 260);
    final edge = WorkflowTransition(
        id: 'original', fromStage: start.id, toStage: end.id, label: 'ادامه');
    final design = WorkflowDesign(
        workflow: _workflow, stages: [start, end], transitions: [edge]);
    WorkflowTransition? inserted;
    await tester.pumpWidget(app(design, insert: (route) => inserted = route));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(inserted, same(edge));
    expect(design.transitions.single, same(edge));
    expect(start.positionY, 30);
    expect(end.positionY, 260);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag retains original stage identity and commit callback',
      (tester) async {
    final task = node(WorkflowStageType.userTask, title: 'بررسی درخواست');
    final design = WorkflowDesign(
        workflow: _workflow, stages: [task], transitions: const []);
    String? moving;
    var committed = false;
    await tester.pumpWidget(app(design,
        move: (id, x, y) => moving = id, moved: () => committed = true));
    await tester.pumpAndSettle();
    await tester.timedDrag(find.text(task.title), const Offset(60, 40),
        const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(moving, task.id);
    expect(committed, isTrue);
    expect(task.positionX, 30);
    expect(task.positionY, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the real canvas with all seven shapes for visual review',
      (tester) async {
    const titles = [
      'شروع',
      'اقدام کاربر',
      'تأیید یا رد',
      'شرط و مسیر',
      'اقدام خودکار',
      'انتظار و زمان‌بندی',
      'پایان فرایند'
    ];
    final stages = [
      for (var i = 0; i < WorkflowStageType.values.length; i++)
        node(WorkflowStageType.values[i],
            title: titles[i], x: i.isEven ? 20 : 260, y: 20 + (i ~/ 2) * 175.0)
    ];
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture-nodes'),
        child: app(WorkflowDesign(
            workflow: _workflow, stages: stages, transitions: const []))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workflow-node-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_WORKFLOW_NODES')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture-nodes')));
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('build/workflow-node-shapes.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });

  testWidgets(
      'saved approval branches render together without modifying the graph',
      (tester) async {
    final approval =
        node(WorkflowStageType.approval, title: 'تأیید درخواست', x: 200, y: 40);
    final targets = [
      for (var i = 0; i < 3; i++)
        WorkflowStage(
            id: 'target-$i',
            key: 'target-$i',
            type: WorkflowStageType.userTask,
            title: ['ادامه فرایند', 'بررسی رد', 'اصلاح درخواست'][i],
            sequence: i + 1,
            configurationComplete: true,
            positionX: [400.0, 0.0, 200.0][i],
            positionY: [260.0, 260.0, 440.0][i])
    ];
    final edges = [
      for (var i = 0; i < 3; i++)
        WorkflowTransition(
            id: 'saved-edge-$i',
            fromStage: approval.id,
            toStage: targets[i].id,
            condition: {
              'action': ['Approve', 'Reject', 'Return'][i]
            })
    ];
    final design = WorkflowDesign(
        workflow: _workflow,
        stages: [approval, ...targets],
        transitions: edges);
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture-routes'), child: app(design)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(3));
    expect(design.transitions, edges);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_WORKFLOW_NODES')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture-routes')));
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('build/workflow-node-routes.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });

  testWidgets(
      'an approval with three saved routes draws three labelled edges, none ending on the plus',
      (tester) async {
    final approval =
        node(WorkflowStageType.approval, title: 'تأیید درخواست', x: 155, y: 215);
    final start = node(WorkflowStageType.start, title: 'شروع', x: 155, y: 40);
    final task =
        node(WorkflowStageType.userTask, title: 'ادامه فرایند', x: 155, y: 390);
    final end = node(WorkflowStageType.end, title: 'پایان', x: 155, y: 565);
    final edges = [
      WorkflowTransition(id: 'e-approve', fromStage: approval.id, toStage: task.id,
          condition: {'action': 'Approve'}),
      WorkflowTransition(id: 'e-reject', fromStage: approval.id, toStage: end.id,
          condition: {'action': 'Reject'}),
      WorkflowTransition(id: 'e-return', fromStage: approval.id, toStage: start.id,
          condition: {'action': 'Return'}),
    ];
    final design = WorkflowDesign(
        workflow: _workflow,
        stages: [start, approval, task, end],
        transitions: edges);
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(design));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    final positions = {
      for (final stage in design.stages)
        stage.id: Offset(stage.positionX, stage.positionY)
    };
    final stages = {for (final stage in design.stages) stage.id: stage};
    final outgoing = <String, List<WorkflowTransition>>{};
    for (final edge in edges) {
      outgoing.putIfAbsent(edge.fromStage, () => []).add(edge);
    }
    final actions = <String>{};
    for (final edge in edges) {
      final geometry = WorkflowGraphGeometry.edge(
          from: stages[edge.fromStage]!,
          to: stages[edge.toStage]!,
          fromPosition: positions[edge.fromStage]!,
          toPosition: positions[edge.toStage]!,
          transition: edge,
          outgoing: outgoing[edge.fromStage]!,
          nodeSize: WorkflowGraphCanvas.nodeSize);
      // Each saved route is its own labelled edge.
      expect(geometry.action, isNotNull);
      actions.add(geometry.action!);
      // The edge ends on the target shape border, not inside it.
      final target = stages[edge.toStage]!;
      final local = geometry.end - positions[edge.toStage]!;
      final toCenter = (Offset.zero & WorkflowGraphCanvas.nodeSize).center - local;
      final dir = toCenter / toCenter.distance;
      final shape = WorkflowGraphGeometry.shape(target.type, WorkflowGraphCanvas.nodeSize);
      expect(shape.contains(local + dir * 1), isTrue,
          reason: '${edge.id} must end on the ${target.type} border');
      expect(shape.contains(local - dir * 1), isFalse,
          reason: '${edge.id} must not end inside the ${target.type}');
      // The "+" insert button sits at the edge midpoint, never at an endpoint.
      expect((geometry.middle - geometry.start).distance, greaterThan(20),
          reason: '${edge.id} start must not be the plus button');
      expect((geometry.middle - geometry.end).distance, greaterThan(20),
          reason: '${edge.id} end must not be the plus button');
    }
    expect(actions, {'Approve', 'Reject', 'Return'});
  });
}
