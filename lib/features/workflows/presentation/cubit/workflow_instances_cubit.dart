import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

enum WorkflowInstancesStatus { loading, ready, failure }

class WorkflowInstancesState extends Equatable {
  const WorkflowInstancesState({
    this.status = WorkflowInstancesStatus.loading,
    this.instances = const [],
    this.offline = false,
    this.message,
  });
  final WorkflowInstancesStatus status;
  final List<WorkflowInstanceSummary> instances;
  final bool offline;
  final String? message;
  @override
  List<Object?> get props => [status, instances, offline, message];
}

class WorkflowInstancesCubit extends Cubit<WorkflowInstancesState> {
  WorkflowInstancesCubit(this._repository)
      : super(const WorkflowInstancesState());
  final WorkflowTaskRepository _repository;

  Future<void> load() async {
    emit(const WorkflowInstancesState());
    try {
      final instances = await _repository.getMyInstances();
      emit(WorkflowInstancesState(
        status: WorkflowInstancesStatus.ready,
        instances: instances,
        offline: _repository.isOfflinePreview,
      ));
    } catch (error) {
      emit(WorkflowInstancesState(
        status: WorkflowInstancesStatus.failure,
        message: error.toString(),
      ));
    }
  }
}
