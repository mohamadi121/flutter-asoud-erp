import '../entities/workflow_task.dart';

/// Optional capability for repositories that fetch every server page.
abstract interface class CompleteWorkflowLists {
  bool get listsAreComplete;
}

/// Optional capability for repositories that can fetch many instance summaries
/// in one call (the cartable's "missing summaries" batch, PA-032).
///
/// Inaccessible or missing names are omitted from the result, never an error.
/// Implementations must fall back to per-instance fetches when the server does
/// not have the batch method, so the cartable keeps working against an older
/// server.
abstract interface class WorkflowInstanceSummariesRepository {
  Future<List<WorkflowInstanceSummary>> getInstanceSummaries(List<String> names);
}

abstract interface class WorkflowTaskRepository {
  bool get isOfflinePreview;
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'});
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status});
  Future<WorkflowInstanceDetail> getInstance(String instance);
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
