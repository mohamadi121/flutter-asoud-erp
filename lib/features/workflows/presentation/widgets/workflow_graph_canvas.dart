import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../domain/entities/workflow_definition.dart';
import 'workflow_graph_geometry.dart';

class WorkflowGraphCanvas extends StatefulWidget {
  const WorkflowGraphCanvas({
    required this.design,
    required this.onOpenStage,
    required this.onMoveStage,
    required this.onMoveEnd,
    required this.onInsertOnTransition,
    required this.onCreateTransition,
    super.key,
  });

  final WorkflowDesign design;
  final ValueChanged<WorkflowStage> onOpenStage;
  final void Function(String id, double x, double y) onMoveStage;
  final VoidCallback onMoveEnd;
  final ValueChanged<WorkflowTransition> onInsertOnTransition;
  final ValueChanged<WorkflowStage> onCreateTransition;

  static const nodeSize = Size(190, 118);

  @override
  State<WorkflowGraphCanvas> createState() => _WorkflowGraphCanvasState();
}

class _WorkflowGraphCanvasState extends State<WorkflowGraphCanvas> {
  final _controller = TransformationController();
  double? _appliedScale;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _position(WorkflowStage stage) {
    if (stage.positionX != 0 || stage.positionY != 0) {
      return Offset(stage.positionX, stage.positionY);
    }
    return Offset(155, 40 + (stage.sequence * 175));
  }

  @override
  Widget build(BuildContext context) {
    final positions = {
      for (final stage in widget.design.stages) stage.id: _position(stage),
    };
    final maxX =
        positions.values.fold<double>(520, (v, p) => math.max(v, p.dx + 260));
    final maxY =
        positions.values.fold<double>(760, (v, p) => math.max(v, p.dy + 220));
    return LayoutBuilder(builder: (context, constraints) {
      final fit = (constraints.maxWidth / maxX).clamp(.55, 1.0);
      if (_appliedScale != fit) {
        _appliedScale = fit;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _controller.value = Matrix4.diagonal3Values(fit, fit, 1);
        });
      }
      return InteractiveViewer(
        transformationController: _controller,
        constrained: false,
        minScale: .55,
        maxScale: 2.2,
        boundaryMargin: const EdgeInsets.all(220),
        child: SizedBox(
          width: maxX,
          height: maxY,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GraphPainter(
                    stages: widget.design.stages,
                    transitions: widget.design.transitions,
                    positions: positions,
                    labelStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: AsoudColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final edge in widget.design.transitions)
                if (positions[edge.fromStage] case final from?)
                  if (positions[edge.toStage] case final to?)
                    Positioned(
                      left: (from.dx + to.dx) / 2 +
                          WorkflowGraphCanvas.nodeSize.width / 2 -
                          18,
                      top: (from.dy + to.dy) / 2 +
                          WorkflowGraphCanvas.nodeSize.height / 2 -
                          18,
                      child: Tooltip(
                        message: 'افزودن مرحله بین این دو مرحله',
                        child: InkWell(
                          onTap: () => widget.onInsertOnTransition(edge),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AsoudColors.primary),
                            ),
                            child: const Icon(Icons.add_rounded,
                                size: 20, color: AsoudColors.primary),
                          ),
                        ),
                      ),
                    ),
              for (final stage in widget.design.stages)
                Positioned(
                  left: positions[stage.id]!.dx,
                  top: positions[stage.id]!.dy,
                  child: GestureDetector(
                    key: ValueKey('workflow-node-${stage.id}'),
                    onPanUpdate: (details) {
                      final current = positions[stage.id]!;
                      widget.onMoveStage(
                        stage.id,
                        math.max(0, current.dx + details.delta.dx),
                        math.max(0, current.dy + details.delta.dy),
                      );
                    },
                    onPanEnd: (_) => widget.onMoveEnd(),
                    child: _GraphNode(
                      stage: stage,
                      outgoing: widget.design.transitions
                          .where((edge) => edge.fromStage == stage.id)
                          .toList(growable: false),
                      onTap: () => widget.onOpenStage(stage),
                      onConnect: () => widget.onCreateTransition(stage),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.stage,
    required this.outgoing,
    required this.onTap,
    required this.onConnect,
  });

  final WorkflowStage stage;
  final List<WorkflowTransition> outgoing;
  final VoidCallback onTap, onConnect;

  @override
  Widget build(BuildContext context) {
    final visual = workflowStageVisual(stage.type);
    return CustomPaint(
      painter: _NodeShapePainter(type: stage.type, color: visual.color),
      child: SizedBox(
        width: WorkflowGraphCanvas.nodeSize.width,
        height: WorkflowGraphCanvas.nodeSize.height,
        child: Stack(clipBehavior: Clip.none, children: [Positioned.fill(child: Material(
          color: Colors.transparent,
          shape: _NodeBorder(stage.type),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: _NodeBorder(stage.type),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: switch (stage.type) {
                    WorkflowStageType.start || WorkflowStageType.end => 55,
                    WorkflowStageType.condition => 49,
                    _ => 28,
                  },
                  vertical: stage.type == WorkflowStageType.condition ? 30 : 21),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(visual.icon, size: 18, color: visual.color),
                  const SizedBox(height: 4),
                  Flexible(child: Tooltip(
                    message: '${stage.title}\n${visual.label}'
                        '${outgoing.isEmpty ? '' : '\n${outgoing.map((e) => persianTransitionLabel(e.label)).join('، ')}'}',
                    child: LayoutBuilder(builder: (_, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: constraints.maxWidth,
                        child: Text(stage.title, textAlign: TextAlign.center, softWrap: true,
                          style: const TextStyle(fontSize: 13, height: 1.2,
                            fontWeight: FontWeight.w900, color: AsoudColors.text))),
                    )),
                  )),
                ],
              ),
            ),
          ),
        )),
          if (outgoing.isNotEmpty && stage.type != WorkflowStageType.approval)
            Positioned(left: WorkflowGraphCanvas.nodeSize.width / 2 + 24,
              top: WorkflowGraphCanvas.nodeSize.height + 3,
              child: SizedBox(width: 130, child: Text(
                outgoing.map((e) => '${persianTransitionLabel(e.label)} ←').join('  '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: visual.color))),
            ),
          if (stage.type != WorkflowStageType.end)
            Positioned(right: 0, bottom: 0, child: Tooltip(
              message: 'ایجاد مسیر جدید',
              child: InkWell(onTap: onConnect, borderRadius: BorderRadius.circular(20),
                child: SizedBox(width: 40, height: 40,
                  child: Icon(Icons.add_link_rounded, size: 20, color: visual.color))),
            )),
        ]),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter(
      {required this.stages,
      required this.transitions,
      required this.positions, required this.labelStyle});
  final List<WorkflowStage> stages;
  final List<WorkflowTransition> transitions;
  final Map<String, Offset> positions;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE9EEF7);
    for (double x = 0; x < size.width; x += 24) {
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), .8, grid);
      }
    }
    final line = Paint()
      ..color = AsoudColors.primary.withValues(alpha: .55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final nodes = {for (final stage in stages) stage.id: stage};
    final outgoing = <String, List<WorkflowTransition>>{};
    for (final edge in transitions) {
      outgoing.putIfAbsent(edge.fromStage, () => []).add(edge);
    }
    final labels = <WorkflowEdgeGeometry>[];
    for (final edge in transitions) {
      final from = positions[edge.fromStage];
      final to = positions[edge.toStage];
      if (from == null || to == null) continue;
      final source = nodes[edge.fromStage], target = nodes[edge.toStage];
      if (source == null || target == null) continue;
      final geometry = WorkflowGraphGeometry.edge(from: source, to: target,
        fromPosition: from, toPosition: to, transition: edge,
        outgoing: outgoing[source.id] ?? const [],
        nodeSize: WorkflowGraphCanvas.nodeSize);
      final end = geometry.end;
      final edgeLine = source.type == WorkflowStageType.condition && edge.condition['result'] is bool
          ? (Paint()..color = edge.condition['result'] == true ? AsoudColors.success : AsoudColors.danger
            ..strokeWidth = 2..style = PaintingStyle.stroke) : line;
      canvas.drawPath(geometry.path, edgeLine);
      final angle = math.atan2(end.dy - geometry.control2.dy, end.dx - geometry.control2.dx);
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 7 * math.cos(angle - .55),
            end.dy - 7 * math.sin(angle - .55))
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 7 * math.cos(angle + .55),
            end.dy - 7 * math.sin(angle + .55));
      canvas.drawPath(arrow, edgeLine);
      if (geometry.action != null) labels.add(geometry);
    }
    // Paint labels after every line, so another route cannot cross their text.
    for (final geometry in labels) {
      if (geometry.action case final action?) {
        final color = action == 'True' ? AsoudColors.success :
            action == 'False' ? AsoudColors.danger : AsoudColors.primary;
        canvas.drawCircle(geometry.start, 3, Paint()..color = color);
        final text = TextPainter(text: TextSpan(text: switch (action) {
          'Approve' => 'تأیید', 'Reject' => 'رد', 'True' => 'برقرار',
          'False' => 'برقرار نیست', _ => 'اصلاح',
        }, style: labelStyle.copyWith(color: color)), textDirection: TextDirection.rtl)..layout();
        final direction = geometry.direction;
        final label = geometry.start + Offset(
          direction.dx > 0 ? 8 : direction.dx < 0 ? -text.width - 8 : 24,
          direction.dy > 0 ? 8 : -text.height - 8);
        canvas.drawRRect(RRect.fromRectAndRadius((label & text.size).inflate(3),
          const Radius.circular(4)), Paint()..color = Colors.white);
        text.paint(canvas, label);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.stages != stages ||
      oldDelegate.transitions != transitions;
}

class _NodeShapePainter extends CustomPainter {
  const _NodeShapePainter({required this.type, required this.color});
  final WorkflowStageType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = type == WorkflowStageType.condition ? const Color(0xffFFF3DE)
          : Color.alphaBlend(color.withValues(alpha: .08), Colors.white);
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = WorkflowGraphGeometry.shape(type, size);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _NodeShapePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class _NodeBorder extends ShapeBorder {
  const _NodeBorder(this.type);
  final WorkflowStageType type;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      WorkflowGraphGeometry.shape(type, rect.size).shift(rect.topLeft);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}

({IconData icon, Color color, String label}) workflowStageVisual(WorkflowStageType type) =>
    switch (type) {
      WorkflowStageType.start => (
          icon: Icons.play_arrow_rounded,
          color: AsoudColors.success,
          label: 'شروع گردش سند'
        ),
      WorkflowStageType.userTask => (
          icon: Icons.fact_check_outlined,
          color: AsoudColors.primary,
          label: 'بررسی یا ویرایش سند'
        ),
      WorkflowStageType.approval => (
          icon: Icons.verified_user_outlined,
          color: AsoudColors.purple,
          label: 'تأیید، رد یا بازگشت'
        ),
      WorkflowStageType.condition => (
          icon: Icons.alt_route_rounded,
          color: Color(0xffBA8427),
          label: 'تصمیم و انشعاب'
        ),
      WorkflowStageType.systemAction => (
          icon: Icons.settings_suggest_outlined,
          color: AsoudColors.cyan,
          label: 'عملیات سیستمی'
        ),
      WorkflowStageType.wait => (
          icon: Icons.schedule_rounded,
          color: AsoudColors.muted,
          label: 'انتظار زمان‌بندی‌شده'
        ),
      WorkflowStageType.end => (
          icon: Icons.stop_circle_outlined,
          color: AsoudColors.danger,
          label: 'پایان گردش سند'
        ),
    };
