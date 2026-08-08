import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

class FrappeWorkflowTaskRepository implements WorkflowTaskRepository {
  const FrappeWorkflowTaskRepository(this._client);
  final FrappeClient _client;

  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async {
    final response = await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_tasks',
      (value) => value,
      data: {'status': status},
    );
    final data = response.data;
    if (data is! List) throw StateError('Invalid workflow task response');
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WorkflowTask(
        id: item['name']?.toString() ?? '',
        instance: item['workflow_instance']?.toString() ?? '',
        stage: item['workflow_stage']?.toString() ?? '',
        title: item['task_title']?.toString() ?? '',
        status: item['status']?.toString() ?? '',
        assignedOn: DateTime.tryParse(item['assigned_on']?.toString() ?? ''),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
  }) async {
    await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.complete_workflow_task',
      (value) => value,
      data: {
        'task': task,
        'action': action,
        if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
      },
    );
  }
}
