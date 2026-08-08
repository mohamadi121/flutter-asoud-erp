import '../entities/workflow_task.dart';

abstract interface class WorkflowTaskRepository {
  bool get isOfflinePreview;
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'});
  Future<WorkflowTaskDetail> getTask(String task);
  Future<void> saveDraft(String task, Map<String, dynamic> values);
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  });
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  });
}
