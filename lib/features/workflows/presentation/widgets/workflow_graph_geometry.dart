import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/workflow_definition.dart';

/// Presentation-only geometry, shared by node paint, ink and edge anchors.
/// Never changes the saved graph, route actions or node coordinates.
abstract final class WorkflowGraphGeometry {
  static Path shape(WorkflowStageType type, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    Path polygon(List<Offset> vertices) => Path()..addPolygon(vertices, true);
    return switch (type) {
      WorkflowStageType.start => Path()
        ..addOval(
            Rect.fromCircle(center: rect.center, radius: math.min(w, h) / 2)),
      WorkflowStageType.userTask => Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      WorkflowStageType.approval => polygon([
          Offset(w * .18, 0),
          Offset(w * .82, 0),
          Offset(w, h / 2),
          Offset(w * .82, h),
          Offset(w * .18, h),
          Offset(0, h / 2)
        ]),
      WorkflowStageType.condition => polygon([
          Offset(w / 2, 0),
          Offset(w, h / 2),
          Offset(w / 2, h),
          Offset(0, h / 2)
        ]),
      WorkflowStageType.systemAction => polygon(
          [Offset(w * .14, 0), Offset(w, 0), Offset(w * .86, h), Offset(0, h)]),
      WorkflowStageType.wait => Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(h / 2))),
      WorkflowStageType.end => _octagon(rect),
    };
  }

  static Path _octagon(Rect bounds) {
    final side = math.min(bounds.width, bounds.height);
    final r = Rect.fromCenter(center: bounds.center, width: side, height: side);
    final cut = side / (2 + math.sqrt(2));
    return Path()
      ..addPolygon([
        Offset(r.left + cut, r.top),
        Offset(r.right - cut, r.top),
        Offset(r.right, r.top + cut),
        Offset(r.right, r.bottom - cut),
        Offset(r.right - cut, r.bottom),
        Offset(r.left + cut, r.bottom),
        Offset(r.left, r.bottom - cut),
        Offset(r.left, r.top + cut),
      ], true);
  }

  static Offset boundary(WorkflowStageType type, Size size, Offset direction) {
    final vector = direction.distance == 0
        ? const Offset(0, 1)
        : direction / direction.distance;
    final center = (Offset.zero & size).center;
    final path = shape(type, size);
    double low = 0, high = size.longestSide;
    for (var i = 0; i < 32; i++) {
      final middle = (low + high) / 2;
      if (path.contains(center + vector * middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return center + vector * ((low + high) / 2);
  }

  static String? decision(WorkflowTransition edge) {
    final action = '${edge.condition['action'] ?? ''}'.trim();
    final value =
        (action.isNotEmpty ? action : edge.label ?? '').trim().toLowerCase();
    return switch (value) {
      '' || 'approve' || 'تأیید' || 'تایید' => 'Approve',
      'reject' || 'رد' => 'Reject',
      'return' || 'اصلاح' || 'بازگشت' || 'بازگشت برای اصلاح' => 'Return',
      _ => null, // Unknown legacy routes are still rendered, never discarded.
    };
  }

  /// Physical left/right, independent of RTL. Only saved outgoing routes count;
  /// this does not invent a new allow-approve flag or a missing connection.
  static Offset approvalDirection(
      WorkflowTransition edge, List<WorkflowTransition> outgoing) {
    final actions = outgoing.map(decision).whereType<String>().toSet();
    final action = decision(edge);
    if (action == null || actions.length <= 1) return const Offset(0, 1);
    if (action == 'Approve') return const Offset(1, 0);
    if (action == 'Reject') return const Offset(-1, 0);
    if (actions.length == 3) return const Offset(0, 1);
    return actions.contains('Approve')
        ? const Offset(-1, 0)
        : const Offset(1, 0);
  }

  static WorkflowEdgeGeometry edge(
      {required WorkflowStage from,
      required WorkflowStage to,
      required Offset fromPosition,
      required Offset toPosition,
      required WorkflowTransition transition,
      required List<WorkflowTransition> outgoing,
      required Size nodeSize}) {
    final delta = toPosition - fromPosition;
    final boolean = from.type == WorkflowStageType.condition && transition.condition['result'] is bool
        ? transition.condition['result'] as bool : null;
    final direction = boolean != null ? Offset(boolean ? 1 : -1, 0)
        : from.type == WorkflowStageType.approval &&
            decision(transition) != null
        ? approvalDirection(transition, outgoing)
        : (delta.distance == 0 ? const Offset(0, 1) : delta / delta.distance);
    final start = fromPosition + boundary(from.type, nodeSize, direction);
    final entry =
        delta.distance == 0 ? const Offset(0, -1) : -delta / delta.distance;
    final end = toPosition + boundary(to.type, nodeSize, entry);
    final distance = (end - start).distance * .4;
    final control = distance.clamp(30.0, 100.0);
    return WorkflowEdgeGeometry(
        start,
        start + direction * control,
        end + entry * control,
        end,
        boolean != null ? (boolean ? 'True' : 'False') :
            from.type == WorkflowStageType.approval ? decision(transition) : null,
        direction,
        (fromPosition + toPosition) / 2 + (Offset.zero & nodeSize).center,
        shape(from.type, nodeSize).getBounds().shift(fromPosition));
  }
}

class WorkflowEdgeGeometry {
  const WorkflowEdgeGeometry(this.start, this.control1, this.control2, this.end,
      this.action, this.direction, this.middle, this.sourceBounds);
  final Offset start, control1, control2, end, direction, middle;
  final Rect sourceBounds;
  final String? action;
  Path get path {
    final delta = end - start;
    final tangent = delta.distance == 0
        ? const Offset(0, 20)
        : delta / delta.distance * (delta.distance * .15).clamp(16.0, 45.0);
    // Keep the existing '+' at exactly its original coordinates, on the line.
    final before = middle - tangent, after = middle + tangent;
    final path = Path()..moveTo(start.dx, start.dy);
    // A route is a back edge only when its target sits behind the source in
    // the exit direction. Measuring from the source center to the target keeps
    // a forward edge that leaves a sideways port from being misread as a return.
    final toTarget = end - sourceBounds.center;
    final behind = toTarget.dx * direction.dx + toTarget.dy * direction.dy < 0;
    if (action != null && behind && !sourceBounds.contains(middle)) {
      // A return route may point to an earlier/sideways node. Escape around
      // the source instead of drawing backwards across its title and icon.
      if (direction.dx.abs() > .5) {
        final x =
            direction.dx > 0 ? sourceBounds.right + 24 : sourceBounds.left - 24;
        final y = middle.dy < sourceBounds.center.dy
            ? sourceBounds.top - 24
            : sourceBounds.bottom + 24;
        path
          ..lineTo(x, start.dy)
          ..lineTo(x, y)
          ..lineTo(middle.dx, y)
          ..lineTo(middle.dx, middle.dy);
      } else {
        final y = sourceBounds.bottom + 24;
        final x = middle.dx < sourceBounds.center.dx
            ? sourceBounds.left - 24
            : sourceBounds.right + 24;
        path
          ..lineTo(start.dx, y)
          ..lineTo(x, y)
          ..lineTo(x, middle.dy)
          ..lineTo(middle.dx, middle.dy);
      }
    } else {
      path.cubicTo(
          control1.dx, control1.dy, before.dx, before.dy, middle.dx, middle.dy);
    }
    return path
      ..cubicTo(after.dx, after.dy, control2.dx, control2.dy, end.dx, end.dy);
  }
}
