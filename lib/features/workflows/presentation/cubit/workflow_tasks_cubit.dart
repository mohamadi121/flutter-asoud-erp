import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../../../../core/utils/failure_message.dart';

enum WorkflowTasksStatus { loading, ready, saving, failure }

class WorkflowTasksState extends Equatable {
  const WorkflowTasksState({
    this.status = WorkflowTasksStatus.loading,
    this.tasks = const [],
    this.offline = false,
    this.filter = 'Open',
    this.message,
  });
  final WorkflowTasksStatus status;
  final List<WorkflowTask> tasks;
  final bool offline;
  final String filter;
  final String? message;
  @override
  List<Object?> get props => [status, tasks, offline, filter, message];
}

class WorkflowTasksCubit extends Cubit<WorkflowTasksState> {
  WorkflowTasksCubit(this._repository) : super(const WorkflowTasksState());
  final WorkflowTaskRepository _repository;

  Future<void> load([String? filter]) async {
    final selected = filter ?? state.filter;
    emit(WorkflowTasksState(filter: selected));
    try {
      final tasks = await _repository.getMyTasks(status: selected);
      emit(WorkflowTasksState(
        status: WorkflowTasksStatus.ready,
        tasks: await _withSubjects(tasks),
        offline: _repository.isOfflinePreview,
        filter: selected,
      ));
    } catch (error) {
      emit(WorkflowTasksState(
          status: WorkflowTasksStatus.failure,
          filter: selected,
          message: failureMessage(error)));
    }
  }

  /// The task list does not carry the instance subject, so resolve it in one
  /// batch call for the cards. A failure here must not hide the tasks: the
  /// list is shown and the cards fall back to the instance id.
  Future<List<WorkflowTask>> _withSubjects(List<WorkflowTask> tasks) async {
    final repository = _repository;
    if (repository is! WorkflowInstanceSummariesRepository) return tasks;
    final summariesRepository = repository as WorkflowInstanceSummariesRepository;
    final names = tasks
        .map((task) => task.instance)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (names.isEmpty) return tasks;
    try {
      final summaries = await summariesRepository.getInstanceSummaries(names);
      final subjects = {for (final item in summaries) item.id: item.subject};
      return [
        for (final task in tasks)
          subjects.containsKey(task.instance)
              ? task.copyWith(subject: subjects[task.instance]!)
              : task,
      ];
    } catch (_) {
      return tasks;
    }
  }

  Future<void> complete(WorkflowTask task, String action) async {
    emit(WorkflowTasksState(
        status: WorkflowTasksStatus.saving,
        tasks: state.tasks,
        offline: state.offline,
        filter: state.filter));
    try {
      await _repository.completeTask(task: task.id, action: action);
      await load();
    } catch (error) {
      emit(WorkflowTasksState(
          status: WorkflowTasksStatus.failure,
          tasks: state.tasks,
          offline: state.offline,
          filter: state.filter,
          message: failureMessage(error)));
    }
  }
}
