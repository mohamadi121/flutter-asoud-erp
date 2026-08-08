import '../entities/workflow_task.dart';

abstract interface class WorkflowTaskRepository {
  bool get isOfflinePreview;
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'});
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
  });
}
