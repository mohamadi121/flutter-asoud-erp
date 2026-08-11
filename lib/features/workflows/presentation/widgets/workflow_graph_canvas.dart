import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/workflow_definition.dart';

class WorkflowGraphCanvas extends StatelessWidget {
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

  Offset _position(WorkflowStage stage) {
    if (stage.positionX != 0 || stage.positionY != 0) {
      return Offset(stage.positionX, stage.positionY);
    }
    return Offset(155, 40 + (stage.sequence * 175));
  }

  @override
  Widget build(BuildContext context) {
    final positions = {
      for (final stage in design.stages) stage.id: _position(stage),
    };
    final maxX =
        positions.values.fold<double>(520, (v, p) => math.max(v, p.dx + 260));
    final maxY =
        positions.values.fold<double>(760, (v, p) => math.max(v, p.dy + 220));
    return InteractiveViewer(
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
                  stages: design.stages,
                  transitions: design.transitions,
                  positions: positions,
                ),
              ),
            ),
            for (final edge in design.transitions)
              if (positions[edge.fromStage] case final from?)
                if (positions[edge.toStage] case final to?)
                  Positioned(
                    left: (from.dx + to.dx) / 2 + nodeSize.width / 2 - 18,
                    top: (from.dy + to.dy) / 2 + nodeSize.height / 2 - 18,
                    child: Tooltip(
                      message: 'افزودن مرحله بین این دو مرحله',
                      child: InkWell(
                        onTap: () => onInsertOnTransition(edge),
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
            for (final stage in design.stages)
              Positioned(
                left: positions[stage.id]!.dx,
                top: positions[stage.id]!.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final current = positions[stage.id]!;
                    onMoveStage(
                      stage.id,
                      math.max(0, current.dx + details.delta.dx),
                      math.max(0, current.dy + details.delta.dy),
                    );
                  },
                  onPanEnd: (_) => onMoveEnd(),
                  child: _GraphNode(
                    stage: stage,
                    outgoing: design.transitions
                        .where((edge) => edge.fromStage == stage.id)
                        .toList(growable: false),
                    onTap: () => onOpenStage(stage),
                    onConnect: () => onCreateTransition(stage),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    final visual = _visual(stage.type);
    return CustomPaint(
      painter: _NodeShapePainter(type: stage.type, color: visual.color),
      child: SizedBox(
        width: WorkflowGraphCanvas.nodeSize.width,
        height: WorkflowGraphCanvas.nodeSize.height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(visual.icon, size: 20, color: visual.color),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(stage.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(visual.label,
                      style: const TextStyle(
                          fontSize: 8, color: AsoudColors.muted)),
                  if (outgoing.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      outgoing.map((e) => '${e.label ?? 'ادامه'} ←').join('  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 8, color: visual.color),
                    ),
                  ],
                  if (stage.type != WorkflowStageType.end)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: InkWell(
                        onTap: onConnect,
                        child: Icon(Icons.add_link_rounded,
                            size: 19, color: visual.color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter(
      {required this.stages,
      required this.transitions,
      required this.positions});
  final List<WorkflowStage> stages;
  final List<WorkflowTransition> transitions;
  final Map<String, Offset> positions;

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
    for (final edge in transitions) {
      final from = positions[edge.fromStage];
      final to = positions[edge.toStage];
      if (from == null || to == null) continue;
      final start = from +
          Offset(WorkflowGraphCanvas.nodeSize.width / 2,
              WorkflowGraphCanvas.nodeSize.height / 2);
      final end = to +
          Offset(WorkflowGraphCanvas.nodeSize.width / 2,
              WorkflowGraphCanvas.nodeSize.height / 2);
      final path = Path()..moveTo(start.dx, start.dy);
      final middle = (start.dy + end.dy) / 2;
      path.cubicTo(start.dx, middle, end.dx, middle, end.dx, end.dy);
      canvas.drawPath(path, line);
      final angle = math.atan2(end.dy - middle, end.dx - end.dx);
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 7 * math.cos(angle - .55),
            end.dy - 7 * math.sin(angle - .55))
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 7 * math.cos(angle + .55),
            end.dy - 7 * math.sin(angle + .55));
      canvas.drawPath(arrow, line);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.transitions != transitions;
}

class _NodeShapePainter extends CustomPainter {
  const _NodeShapePainter({required this.type, required this.color});
  final WorkflowStageType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = switch (type) {
      WorkflowStageType.condition => Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close(),
      WorkflowStageType.systemAction => Path()
        ..moveTo(20, 0)
        ..lineTo(size.width - 20, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width - 20, size.height)
        ..lineTo(20, size.height)
        ..lineTo(0, size.height / 2)
        ..close(),
      WorkflowStageType.start || WorkflowStageType.end => Path()
        ..addOval(Rect.fromLTWH(28, 0, size.width - 56, size.height)),
      _ => Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(18))),
    };
    canvas.drawShadow(path, Colors.black.withValues(alpha: .13), 7, false);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _NodeShapePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

({IconData icon, Color color, String label}) _visual(WorkflowStageType type) =>
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
          color: AsoudColors.warning,
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
