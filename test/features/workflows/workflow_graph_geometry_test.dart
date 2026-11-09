import 'dart:math' as math;

import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_graph_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(190, 118);
WorkflowTransition route(String action) => WorkflowTransition(
    id: 'saved-$action',
    fromStage: 'approval',
    toStage: 'destination-$action',
    condition: {'action': action});

/// True when [local] sits on the shape border: 1px toward the center is
/// inside and 1px away is outside.
bool onShapeBorder(WorkflowStageType type, Offset local) {
  final path = WorkflowGraphGeometry.shape(type, size);
  final toCenter = (Offset.zero & size).center - local;
  if (toCenter.distance == 0) return false;
  final dir = toCenter / toCenter.distance;
  return path.contains(local + dir * 1) && !path.contains(local - dir * 1);
}

/// Longest run of collinear samples along the path. A smooth cubic stays
/// short; the return-route escape detour is a polyline with a long straight
/// run, so this separates the two.
double longestStraightRun(Path path) {
  final metric = path.computeMetrics().single;
  final points = <Offset>[
    for (double d = 0; d < metric.length; d += 1)
      metric.getTangentForOffset(d)!.position,
  ];
  double best = 0;
  for (var i = 0; i + 2 < points.length; i++) {
    final a = points[i], b = points[i + 1];
    double cross(Offset p) =>
        (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (cross(points[i + 2]).abs() > .5) continue;
    var j = i + 2;
    while (j + 1 < points.length && cross(points[j + 1]).abs() <= .5) {
      j++;
    }
    best = math.max(best, (points[j] - a).distance);
    i = j;
  }
  return best;
}

WorkflowStage stageAt(WorkflowStageType type, int sequence, String id) =>
    WorkflowStage(
        id: id,
        key: id,
        type: type,
        title: id,
        sequence: sequence,
        configurationComplete: true);

void main() {
  test('condition boolean exits are independent and retain saved identities', () {
    const source = WorkflowStage(id: 'gate', key: 'gate', type: WorkflowStageType.condition,
      title: 'شرط و مسیر', sequence: 2, configurationComplete: true);
    const destination = WorkflowStage(id: 'end', key: 'end', type: WorkflowStageType.end,
      title: 'پایان', sequence: 3, configurationComplete: true);
    for (final result in [true, false]) {
      final edge = WorkflowTransition(id: 'edge-$result', fromStage: 'gate', toStage: 'end', condition: {'result': result});
      final geometry = WorkflowGraphGeometry.edge(from: source, to: destination,
        fromPosition: const Offset(100, 100), toPosition: const Offset(100, 400),
        transition: edge, outgoing: [edge], nodeSize: size);
      expect(geometry.direction.dx, result ? 1 : -1);
      expect(geometry.action, result ? 'True' : 'False');
      expect(edge.condition, {'result': result});
      expect(edge.id, 'edge-$result');
    }
  });
  final combinations = <Map<String, Offset>>[
    {'Approve': const Offset(0, 1)},
    {'Reject': const Offset(0, 1)},
    {'Return': const Offset(0, 1)},
    {'Approve': const Offset(1, 0), 'Reject': const Offset(-1, 0)},
    {'Approve': const Offset(1, 0), 'Return': const Offset(-1, 0)},
    {'Reject': const Offset(-1, 0), 'Return': const Offset(1, 0)},
    {
      'Approve': const Offset(1, 0),
      'Reject': const Offset(-1, 0),
      'Return': const Offset(0, 1)
    },
  ];
  for (final combination in combinations) {
    test('locked physical approval ports: ${combination.keys.join('+')}', () {
      final edges = combination.keys.map(route).toList();
      final before = List<WorkflowTransition>.of(edges);
      for (final edge in edges) {
        expect(WorkflowGraphGeometry.approvalDirection(edge, edges),
            combination[edge.condition['action']]);
      }
      expect(edges, before);
    });
  }

  test(
      'legacy Persian labels, explicit actions and unknown exits retain identity',
      () {
    const approve = WorkflowTransition(
        id: 'a', fromStage: 'x', toStage: 'y', label: 'تأیید');
    const back = WorkflowTransition(
        id: 'b', fromStage: 'x', toStage: 'old', label: 'بازگشت برای اصلاح');
    const reject = WorkflowTransition(
        id: 'c',
        fromStage: 'x',
        toStage: 'end',
        label: 'تأیید',
        condition: {'action': 'Reject'});
    const unknown = WorkflowTransition(
        id: 'd', fromStage: 'x', toStage: 'old', label: 'مسیر سفارشی');
    expect(WorkflowGraphGeometry.decision(approve), 'Approve');
    expect(WorkflowGraphGeometry.decision(back), 'Return');
    expect(WorkflowGraphGeometry.decision(reject), 'Reject');
    expect(WorkflowGraphGeometry.decision(unknown), isNull);
  });

  test(
      'removing an exit reanchors the remaining saved route without changing it',
      () {
    final approve = route('Approve'), reject = route('Reject');
    expect(WorkflowGraphGeometry.approvalDirection(approve, [approve, reject]),
        const Offset(1, 0));
    expect(WorkflowGraphGeometry.approvalDirection(approve, [approve]),
        const Offset(0, 1));
    expect(approve.id, 'saved-Approve');
    expect(approve.toStage, 'destination-Approve');
    expect(approve.condition, {'action': 'Approve'});
  });

  test('all seven silhouettes are distinct and centered', () {
    final signatures = <String>{};
    for (final type in WorkflowStageType.values) {
      final path = WorkflowGraphGeometry.shape(type, size);
      expect(path.contains(const Offset(95, 59)), isTrue);
      signatures.add([
        for (var y = 0; y < 118; y += 4)
          for (var x = 0; x < 190; x += 4)
            path.contains(Offset(x.toDouble(), y.toDouble())) ? '1' : '0'
      ].join());
    }
    expect(signatures, hasLength(7));
    final circle =
        WorkflowGraphGeometry.shape(WorkflowStageType.start, size).getBounds();
    expect(circle.width, circle.height);
    final end = WorkflowGraphGeometry.shape(WorkflowStageType.end, size);
    expect(end.contains(const Offset(37, 1)), isFalse);
    expect(end.contains(const Offset(95, 1)), isTrue);
  });

  for (final offset in [
    const Offset(0, -260),
    const Offset(300, 0),
    const Offset(-300, 0)
  ]) {
    test('single bottom approval exit to $offset never crosses its own node',
        () {
      const source = WorkflowStage(
          id: 'approval',
          key: 'approval',
          type: WorkflowStageType.approval,
          title: 'تأیید',
          sequence: 0,
          configurationComplete: true);
      const target = WorkflowStage(
          id: 'target',
          key: 'target',
          type: WorkflowStageType.userTask,
          title: 'مقصد',
          sequence: 1,
          configurationComplete: true);
      final transition = route('Return');
      final geometry = WorkflowGraphGeometry.edge(
          from: source,
          to: target,
          fromPosition: Offset.zero,
          toPosition: offset,
          transition: transition,
          outgoing: [transition],
          nodeSize: size);
      final silhouette = WorkflowGraphGeometry.shape(source.type, size);
      final metric = geometry.path.computeMetrics().single;
      for (double distance = 2; distance < metric.length - 2; distance += 2) {
        expect(
            silhouette.contains(metric.getTangentForOffset(distance)!.position),
            isFalse);
      }
    });
  }

  for (final type in WorkflowStageType.values) {
    for (final offset in [
      const Offset(0, 240),
      const Offset(280, 0),
      const Offset(-280, -200)
    ]) {
      test(
          'edge touches $type outline, including reverse/horizontal routes $offset',
          () {
        final stage = WorkflowStage(
            id: 'a',
            key: 'a',
            type: type,
            title: 'مرحله',
            sequence: 0,
            configurationComplete: true);
        final destination = WorkflowStage(
            id: 'b',
            key: 'b',
            type: type,
            title: 'مقصد',
            sequence: 1,
            configurationComplete: true);
        final edge = route('Approve');
        final geometry = WorkflowGraphGeometry.edge(
            from: stage,
            to: destination,
            fromPosition: Offset.zero,
            toPosition: offset,
            transition: edge,
            outgoing: [edge],
            nodeSize: size);
        final path = WorkflowGraphGeometry.shape(type, size);
        final targetDirection = offset / offset.distance;
        expect(
            path.contains(geometry.start - geometry.direction * .05), isTrue);
        expect(
            path.contains(geometry.start + geometry.direction * .05), isFalse);
        expect(path.contains(geometry.end - offset + targetDirection * .05),
            isTrue);
        expect(path.contains(geometry.end - offset - targetDirection * .05),
            isFalse);
        expect(geometry.path.computeMetrics().single.length, greaterThan(0));
        expect(geometry.middle, offset / 2 + const Offset(95, 59));
        final metric = geometry.path.computeMetrics().single;
        var closest = double.infinity;
        for (double distance = 0; distance < metric.length; distance += .5) {
          final point = metric.getTangentForOffset(distance)!.position;
          final gap = (point - geometry.middle).distance;
          if (gap < closest) closest = gap;
        }
        expect(closest, lessThan(.6),
            reason: 'The unchanged insert button must remain on its line');
      });
    }
  }

  // A vertical stack, as the designer lays out a saved approval: the three
  // saved routes leave the hexagon and must each land on the target border.
  final approval = stageAt(WorkflowStageType.approval, 1, 'appr');
  final start = stageAt(WorkflowStageType.start, 0, 'start');
  final task = stageAt(WorkflowStageType.userTask, 2, 'task');
  final end = stageAt(WorkflowStageType.end, 3, 'end');
  final approvalEdges = [
    WorkflowTransition(id: 'e-approve', fromStage: 'appr', toStage: 'task',
        condition: {'action': 'Approve'}),
    WorkflowTransition(id: 'e-reject', fromStage: 'appr', toStage: 'end',
        condition: {'action': 'Reject'}),
    WorkflowTransition(id: 'e-return', fromStage: 'appr', toStage: 'start',
        condition: {'action': 'Return'}),
  ];
  final approvalStages = {
    'appr': approval, 'start': start, 'task': task, 'end': end
  };
  Offset approvalPos(WorkflowStage s) => Offset(155, 40 + s.sequence * 175);
  WorkflowEdgeGeometry approvalGeometry(WorkflowTransition edge) =>
      WorkflowGraphGeometry.edge(
          from: approval,
          to: approvalStages[edge.toStage]!,
          fromPosition: approvalPos(approval),
          toPosition: approvalPos(approvalStages[edge.toStage]!),
          transition: edge,
          outgoing: approvalEdges,
          nodeSize: size);

  test('every saved approval route ends on the target shape border', () {
    for (final edge in approvalEdges) {
      final geometry = approvalGeometry(edge);
      final target = approvalStages[edge.toStage]!;
      expect(onShapeBorder(target.type, geometry.end - approvalPos(target)),
          isTrue,
          reason: '${edge.condition['action']} must end on the ${target.type} border');
    }
  });

  test('forward approval routes are smooth, not the return escape detour', () {
    // Approve and Reject point forward (down the stack) even though they leave
    // a sideways port; only Return points back to an earlier stage.
    expect(longestStraightRun(approvalGeometry(approvalEdges[0]).path),
        lessThan(100),
        reason: 'Approve must be a smooth cubic, not an escape polyline');
    expect(longestStraightRun(approvalGeometry(approvalEdges[1]).path),
        lessThan(100),
        reason: 'Reject must be a smooth cubic, not an escape polyline');
    expect(longestStraightRun(approvalGeometry(approvalEdges[2]).path),
        greaterThan(100),
        reason: 'Return must keep its escape detour around the source');
  });

  test('the return route reaches the earlier stage border', () {
    final geometry = approvalGeometry(approvalEdges[2]);
    expect(onShapeBorder(start.type, geometry.end - approvalPos(start)), isTrue,
        reason: 'Return must end on the earlier start stage border');
  });
}
