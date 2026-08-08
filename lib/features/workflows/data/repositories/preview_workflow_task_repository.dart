import '../../../../core/network/api_exception.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

class PreviewWorkflowTaskRepository implements WorkflowTaskRepository {
  PreviewWorkflowTaskRepository(this._remote);
  final WorkflowTaskRepository _remote;
  bool _offline = false;
  final _tasks = <WorkflowTask>[
    WorkflowTask(
      id: 'WFT-OFFLINE-001',
      instance: 'WFI-OFFLINE-001',
      stage: 'STAGE-OFFLINE-REVIEW',
      title: 'بررسی درخواست خرید',
      status: 'Open',
      assignedOn: DateTime(2026, 8, 9, 9, 30),
    ),
  ];

  @override
  bool get isOfflinePreview => _offline;

  bool _networkFailure(Object error) =>
      error is ApiException &&
      (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout);

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async {
    try {
      final result = await _remote.getMyTasks(status: status);
      _offline = false;
      return result;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _offline = true;
      return _tasks.where((task) => task.status == status).toList();
    }
  }

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
  }) async {
    if (!_offline) {
      try {
        await _remote.completeTask(
            task: task, action: action, comment: comment);
        return;
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _offline = true;
      }
    }
    final index = _tasks.indexWhere((item) => item.id == task);
    if (index < 0) throw StateError('Offline task not found');
    final old = _tasks[index];
    _tasks[index] = WorkflowTask(
      id: old.id,
      instance: old.instance,
      stage: old.stage,
      title: old.title,
      status: action == 'Reject' ? 'Rejected' : 'Completed',
      assignedOn: old.assignedOn,
    );
  }
}
