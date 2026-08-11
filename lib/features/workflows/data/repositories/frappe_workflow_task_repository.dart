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
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_tasks',
      data: {'status': status},
    );
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
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_instances',
      data: {if (status != null) 'status': status},
    );
    if (data is! List) throw StateError('Invalid workflow instance response');
    return data
        .whereType<Map>()
        .map((raw) => _instance(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.get_workflow_instance',
      data: {'instance': instance},
    );
    if (data is! Map) throw StateError('Invalid workflow instance detail');
    final item = Map<String, dynamic>.from(data);
    final rawActivities = item['activities'];
    return WorkflowInstanceDetail(
      summary: _instance(item),
      activities: rawActivities is List
          ? rawActivities.whereType<Map>().map((raw) {
              final activity = Map<String, dynamic>.from(raw);
              return WorkflowTaskActivity(
                actor: activity['actor']?.toString() ?? '',
                action: activity['action']?.toString() ?? '',
                comment: activity['comment']?.toString() ?? '',
                createdOn:
                    DateTime.tryParse(activity['created_on']?.toString() ?? ''),
              );
            }).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.complete_workflow_task',
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
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.get_workflow_task',
      data: {'task': task},
    );
    if (data is! Map) throw StateError('Invalid task detail response');
    final item = Map<String, dynamic>.from(data);
    final config = item['config'] is Map
        ? Map<String, dynamic>.from(item['config'] as Map)
        : <String, dynamic>{};
    final rawFields = config['form_fields'];
    final rawHistory = item['history'];
    final rawPreviousData = item['previous_data'];
    final document = item['document'] is Map
        ? Map<String, dynamic>.from(item['document'] as Map)
        : const <String, dynamic>{};
    final documentValues = document['values'];
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
      commentRequired: config['comment_required'] == true,
      activityType: config['activity_type']?.toString() ?? '',
      previousData: rawPreviousData is List
          ? rawPreviousData.whereType<Map>().map((raw) {
              final section = Map<String, dynamic>.from(raw);
              final values = section['values'];
              return WorkflowTaskDataSection(
                title: section['title']?.toString() ?? 'اطلاعات مرحله قبل',
                values: values is List
                    ? values.whereType<Map>().map((rawValue) {
                        final value = Map<String, dynamic>.from(rawValue);
                        return WorkflowTaskDataValue(
                          key: value['key']?.toString() ?? '',
                          label: value['label']?.toString() ?? '',
                          value: value['value'],
                        );
                      }).toList(growable: false)
                    : const [],
              );
            }).toList(growable: false)
          : const [],
      referenceDoctype: document['doctype']?.toString() ?? '',
      referenceName: document['name']?.toString() ?? '',
      documentValues: documentValues is List
          ? documentValues.whereType<Map>().map((raw) {
              final value = Map<String, dynamic>.from(raw);
              return WorkflowTaskDataValue(
                key: value['key']?.toString() ?? '',
                label: value['label']?.toString() ?? '',
                value: value['value'],
              );
            }).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.save_workflow_task_draft',
      data: {'task': task, 'response': values},
    );
  }

  @override
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.upload_workflow_attachment',
      data: {
        'task': task,
        'filename': filename,
        'content_base64': base64Encode(bytes),
      },
    );
    if (data is! Map) throw StateError('Invalid attachment response');
    return data['file_url']?.toString() ?? '';
  }
}

WorkflowInstanceSummary _instance(Map<String, dynamic> item) =>
    WorkflowInstanceSummary(
      id: item['name']?.toString() ?? '',
      subject: item['subject']?.toString() ?? '',
      status: item['status']?.toString() ?? '',
      workflowDefinition: item['workflow_definition']?.toString() ?? '',
      currentStage: item['current_stage']?.toString() ?? '',
      currentStageTitle: item['current_stage_title']?.toString() ?? '',
      currentAssignees: item['current_assignees'] is List
          ? (item['current_assignees'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      referenceDoctype: item['reference_doctype']?.toString() ?? '',
      referenceName: item['reference_name']?.toString() ?? '',
      startedOn: DateTime.tryParse(item['started_on']?.toString() ?? ''),
      completedOn: DateTime.tryParse(item['completed_on']?.toString() ?? ''),
    );
