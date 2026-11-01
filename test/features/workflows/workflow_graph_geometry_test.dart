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

void main() {
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
}
