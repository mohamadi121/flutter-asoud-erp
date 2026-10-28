import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const workflow = WorkflowDefinition(id: 'design', code: 'design', title: 'گردش آزمایشی',
    targetDoctype: 'ASOUD Workflow Request', status: WorkflowDefinitionStatus.inactive,
    isLocked: true, version: 1, stepsCount: 0, modified: null);

WorkflowStage stage(String id, WorkflowStageType type, int sequence) => WorkflowStage(
    id: id, key: id, type: type, title: 'مرحله', sequence: sequence,
    configurationComplete: false);

class Repository extends Fake implements WorkflowRepository {
  Repository({this.withEnd = false, this.ambiguous = false});
  final bool withEnd, ambiguous;
  late WorkflowDesign design = WorkflowDesign(workflow: workflow,
      stages: [stage('start', WorkflowStageType.start, 0),
        if (withEnd) stage('end', WorkflowStageType.end, 2)],
      transitions: [if (withEnd)
        const WorkflowTransition(id: 'route', fromStage: 'start', toStage: 'end', label: ''),
        if (ambiguous)
        const WorkflowTransition(id: 'other-route', fromStage: 'start', toStage: 'end', label: '')]);
  int additions = 0, insertions = 0;
  @override
  Future<WorkflowDesign> getDesign(String definition) async => design;
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: [], modules: []);
  @override
  Future<WorkflowDesign> addStage({required String definition,
      required String afterStage, required WorkflowStageType type}) async {
    additions++;
    final created = stage(type == WorkflowStageType.end ? 'end' : 'task', type, additions);
    design = WorkflowDesign(workflow: workflow, stages: [...design.stages, created],
        transitions: [...design.transitions, WorkflowTransition(id: 'edge-$additions',
          fromStage: afterStage, toStage: created.id, label: '')]);
    return design;
  }
  @override
  Future<WorkflowDesign> insertStage({required String definition,
      required String transition, required WorkflowStageType type}) async {
    insertions++;
    expect(transition, 'route');
    design = WorkflowDesign(workflow: workflow,
        stages: [...design.stages, stage('task', type, 1)], transitions: const [
          WorkflowTransition(id: 'first', fromStage: 'start', toStage: 'task', label: ''),
          WorkflowTransition(id: 'last', fromStage: 'task', toStage: 'end', label: '')]);
    return design;
  }
}

void main() {
  test('first user task returns its own identity and supplies a real End', () async {
    final repository = Repository();
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'design');
    addTearDown(cubit.close);
    await cubit.load();
    final created = await cubit.addStage(WorkflowStageType.userTask);
    expect(created?.id, 'task');
    expect(repository.additions, 2);
    expect(cubit.state.design!.stages.where((s) => s.type == WorkflowStageType.end), hasLength(1));
  });

  test('adds before a terminal node instead of appending after End', () async {
    final repository = Repository(withEnd: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'design');
    addTearDown(cubit.close);
    await cubit.load();
    expect((await cubit.addStage(WorkflowStageType.userTask))?.id, 'task');
    expect(repository.insertions, 1);
    expect(repository.additions, 0);
  });

  test('ambiguous terminal routes are not silently chosen', () async {
    final repository = Repository(withEnd: true, ambiguous: true);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: 'design');
    addTearDown(cubit.close);
    await cubit.load();
    expect(await cubit.addStage(WorkflowStageType.userTask), isNull);
    expect(repository.insertions, 0);
    expect(repository.additions, 0);
    expect(cubit.state.status, WorkflowDesignerStatus.failure);
  });
}
