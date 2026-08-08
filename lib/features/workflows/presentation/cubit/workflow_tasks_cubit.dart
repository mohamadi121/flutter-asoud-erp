import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

enum WorkflowTasksStatus { loading, ready, saving, failure }

class WorkflowTasksState extends Equatable {
  const WorkflowTasksState({
    this.status = WorkflowTasksStatus.loading,
    this.tasks = const [],
    this.offline = false,
    this.message,
  });
  final WorkflowTasksStatus status;
  final List<WorkflowTask> tasks;
  final bool offline;
  final String? message;
  @override
  List<Object?> get props => [status, tasks, offline, message];
}

class WorkflowTasksCubit extends Cubit<WorkflowTasksState> {
  WorkflowTasksCubit(this._repository) : super(const WorkflowTasksState());
  final WorkflowTaskRepository _repository;

  Future<void> load() async {
    emit(const WorkflowTasksState());
    try {
      final tasks = await _repository.getMyTasks();
      emit(WorkflowTasksState(
        status: WorkflowTasksStatus.ready,
        tasks: tasks,
        offline: _repository.isOfflinePreview,
      ));
    } catch (error) {
      emit(WorkflowTasksState(
          status: WorkflowTasksStatus.failure, message: error.toString()));
    }
  }

  Future<void> complete(WorkflowTask task, String action) async {
    emit(WorkflowTasksState(
        status: WorkflowTasksStatus.saving,
        tasks: state.tasks,
        offline: state.offline));
    try {
      await _repository.completeTask(task: task.id, action: action);
      await load();
    } catch (error) {
      emit(WorkflowTasksState(
          status: WorkflowTasksStatus.failure,
          tasks: state.tasks,
          offline: state.offline,
          message: error.toString()));
    }
  }
}
