import '../../../../core/network/frappe_client.dart';
import 'dart:convert';
import '../../domain/entities/workflow_task.dart';
import '../../domain/entities/workflow_definition.dart';
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
    Map<String, dynamic> response = const {},
  }) async {
    await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.complete_workflow_task',
      (value) => value,
      data: {
        'task': task,
        'action': action,
        if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
        'response': response,
      },
    );
  }

  @override
  Future<WorkflowTaskDetail> getTask(String task) async {
    final response = await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.get_workflow_task',
      (value) => value,
      data: {'task': task},
    );
    if (response.data is! Map) throw StateError('Invalid task detail response');
    final item = Map<String, dynamic>.from(response.data as Map);
    final config = item['config'] is Map
        ? Map<String, dynamic>.from(item['config'] as Map)
        : <String, dynamic>{};
    final rawFields = config['form_fields'];
    final rawHistory = item['history'];
    final taskEntity = WorkflowTask(
      id: item['name']?.toString() ?? '',
      instance: item['workflow_instance']?.toString() ?? '',
      stage: item['workflow_stage']?.toString() ?? '',
      title: item['task_title']?.toString() ?? '',
      status: item['status']?.toString() ?? '',
    );
    return WorkflowTaskDetail(
      task: taskEntity,
      stageType: item['stage_type']?.toString() ?? '',
      fields: rawFields is List
          ? rawFields
              .whereType<Map>()
              .map(WorkflowFormFieldDefinition.fromMap)
              .toList(growable: false)
          : const [],
      values: item['draft'] is Map
          ? Map<String, dynamic>.from(item['draft'] as Map)
          : const {},
      activities: rawHistory is List
          ? rawHistory.whereType<Map>().map((raw) {
              final value = Map<String, dynamic>.from(raw);
              return WorkflowTaskActivity(
                actor: value['actor']?.toString() ?? '',
                action: value['action']?.toString() ?? '',
                comment: value['comment']?.toString() ?? '',
                createdOn:
                    DateTime.tryParse(value['created_on']?.toString() ?? ''),
              );
            }).toList(growable: false)
          : const [],
      allowReject: config['allow_reject'] == true,
      allowReturn: config['allow_return'] == true,
    );
  }

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {
    await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.save_workflow_task_draft',
      (value) => value,
      data: {'task': task, 'response': values},
    );
  }

  @override
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  }) async {
    final response = await _client.callAsoudMethod<Object?>(
      'asoud_erp.api.v1.workflow_runtime.upload_workflow_attachment',
      (value) => value,
      data: {
        'task': task,
        'filename': filename,
        'content_base64': base64Encode(bytes),
      },
    );
    if (response.data is! Map) throw StateError('Invalid attachment response');
    return (response.data as Map)['file_url']?.toString() ?? '';
  }
}
