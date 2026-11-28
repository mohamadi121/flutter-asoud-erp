import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import 'dart:convert';
import 'dart:math';
import '../../domain/entities/workflow_task.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../../domain/repositories/workflow_task_supplementary_repository.dart';

class FrappeWorkflowTaskRepository
    implements
        WorkflowTaskRepository,
        CompleteWorkflowLists,
        WorkflowTaskSupplementaryRepository,
        WorkflowInstanceSummariesRepository {
  FrappeWorkflowTaskRepository(this._client);
  final FrappeClient _client;
  bool _complete = true;

  /// The `request_id` of the last completion whose outcome is still unknown
  /// (a network/timeout failure means the server may have applied the
  /// decision). Kept per task so a retry of the same decision re-sends the
  /// same id and the server replays the stored result instead of erroring.
  final Map<String, String> _pendingRequestIds = {};

  static String _newRequestId() =>
      'task-${List.generate(16, (_) => Random.secure().nextInt(16)).map((n) => n.toRadixString(16)).join()}';

  /// A failure whose outcome is unknown: the request may have reached the
  /// server, so the same `request_id` must be reused on retry.
  static bool _outcomeUnknown(Object error) =>
      error is ApiException &&
      (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout);

  @override
  bool get isOfflinePreview => false;

  @override
  bool get listsAreComplete => _complete;

  /// The server caps a single batch call at 100 instance names.
  static const _summaryBatchSize = 100;

  @override
  Future<List<WorkflowInstanceSummary>> getInstanceSummaries(
      List<String> names) async {
    final summaries = <String, WorkflowInstanceSummary>{};
    for (var offset = 0; offset < names.length; offset += _summaryBatchSize) {
      final chunk = names.skip(offset).take(_summaryBatchSize).toList();
      try {
        final data = await _client.callAsoudMethod(
          'asoud_erp.api.v1.workflow_runtime.get_workflow_instance_summaries',
          data: {'names': chunk},
        );
        if (data is! List) {
          throw StateError('پاسخ خلاصهٔ گردش‌ها معتبر نیست.');
        }
        for (final raw in data.whereType<Map>()) {
          final summary = _instance(Map<String, dynamic>.from(raw));
          if (summary.id.isNotEmpty) summaries[summary.id] = summary;
        }
      } on ApiException catch (error) {
        // An older server has no batch method: Frappe answers 417 with the raw
        // "Failed to get method" text. Fall back to the per-instance fetch so
        // the cartable still works against the live server.
        if (error.statusCode == 417 &&
            error.message.contains('get_workflow_instance_summaries')) {
          await _fetchSummariesOneByOne(chunk, summaries);
        } else {
          rethrow;
        }
      }
    }
    return summaries.values.toList(growable: false);
  }

  Future<void> _fetchSummariesOneByOne(
      List<String> names, Map<String, WorkflowInstanceSummary> into) async {
    for (final name in names) {
      try {
        final detail = await getInstance(name);
        into[detail.summary.id] = detail.summary;
      } catch (_) {
        // A single unreadable instance must not break the whole cartable; the
        // page already reports the count of unavailable records.
      }
    }
  }

  Future<List<dynamic>> _allPages(
      String method, Map<String, dynamic> filters) async {
    final rows = <dynamic>[];
    final visited = <String>{};
    String? cursor = '0';
    do {
      if (!visited.add(cursor!)) {
        throw StateError('صفحه‌بندی کارتابل معتبر نیست.');
      }
      final response = await _client.callAsoudMethod(method,
          data: {...filters, 'start': cursor, 'paged': true});
      if (response is List) {
        // Older server without paging: the whole list is the answer.
        _complete = false;
        return response;
      }
      if (response is! Map || response['items'] is! List) {
        throw StateError('پاسخ کارتابل از سرور معتبر نیست.');
      }
      rows.addAll(response['items'] as List);
      cursor = response['next_cursor']?.toString();
    } while (cursor != null);
    return rows;
  }

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async {
    final data = await _allPages(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_tasks',
      {'status': status},
    );
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WorkflowTask(
        id: item['name']?.toString() ?? '',
        instance: item['workflow_instance']?.toString() ?? '',
        stage: item['workflow_stage']?.toString() ?? '',
        title: item['task_title']?.toString() ?? '',
        status: item['status']?.toString() ?? '',
        assignedOn: DateTime.tryParse(item['assigned_on']?.toString() ?? ''),
        dueOn: DateTime.tryParse(item['due_on']?.toString() ?? ''),
        reminderSentOn:
            DateTime.tryParse(item['reminder_sent_on']?.toString() ?? ''),
        escalatedOn: DateTime.tryParse(item['escalated_on']?.toString() ?? ''),
        followup: item['followup']?.toString() ?? '',
        action: item['action']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async {
    final data = await _allPages(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_instances',
      {if (status != null) 'status': status},
    );
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
      canRestart: item['can_restart'] == true || item['can_restart'] == 1,
      activities: rawActivities is List
          ? rawActivities.whereType<Map>().map(_activity).toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> _completeData({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
    Map<String, dynamic>? supplementaryValues,
    required String requestId,
  }) =>
      {
        'task': task,
        'action': action,
        if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
        'response': response,
        // The supplementary form travels separately from the decision response.
        if (supplementaryValues != null && supplementaryValues.isNotEmpty)
          'supplementary_values': supplementaryValues,
        'request_id': requestId,
      };

  /// Sends a completion with an idempotent `request_id`. The id is reused when
  /// the previous attempt failed with an unknown outcome (network/timeout) so
  /// the server replays the stored result; a definitive answer (success or a
  /// server refusal) clears it so the next attempt starts fresh.
  Future<void> _sendCompletion({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
    Map<String, dynamic>? supplementaryValues,
  }) async {
    final requestId = _pendingRequestIds[task] ?? _newRequestId();
    // Remember the id before sending so a network/timeout failure (unknown
    // outcome) reuses it on the retry; a definitive answer clears it.
    _pendingRequestIds[task] = requestId;
    try {
      await _client.callAsoudMethod(
        'asoud_erp.api.v1.workflow_runtime.complete_workflow_task',
        data: _completeData(
            task: task,
            action: action,
            comment: comment,
            response: response,
            supplementaryValues: supplementaryValues,
            requestId: requestId),
      );
      _pendingRequestIds.remove(task);
    } catch (error) {
      if (!_outcomeUnknown(error)) _pendingRequestIds.remove(task);
      rethrow;
    }
  }

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) =>
      _sendCompletion(
          task: task, action: action, comment: comment, response: response);

  @override
  Future<void> completeTaskWithSupplementary({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
    required Map<String, dynamic> supplementaryValues,
  }) =>
      _sendCompletion(
          task: task,
          action: action,
          comment: comment,
          response: response,
          supplementaryValues: supplementaryValues);

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
      action: item['action']?.toString() ?? '',
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
      actionSchema: item['action_schema'] is Map ? Map<String, dynamic>.from(item['action_schema'] as Map) : const {},
      actionForm: item['action_form']?.toString() ?? '', actionCompany: item['action_company']?.toString() ?? '',
      actionMode: config['result_mode']?.toString() ?? '', requiresClaim: item['requires_claim'] == true,
      allowDraft: item['allow_draft'] != false, allowAddAttachments: item['allow_add_attachments'] == true,
      documentAccess: config['document_access']?.toString() ?? 'Read Only',
      allowReassign: item['allow_reassign'] == true,
      allowOriginalAccess: item['allow_original_access'] != false,
      values: item['action_values'] is Map ? Map<String, dynamic>.from(item['action_values'] as Map) : item['draft'] is Map
          ? Map<String, dynamic>.from(item['draft'] as Map)
          : const {},
      activities: rawHistory is List
          ? rawHistory.whereType<Map>().map(_activity).toList(growable: false)
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
      requestName: item['request_name']?.toString() ?? '',
      submittedForm: item['submitted_form'] is Map
          ? Map<String, dynamic>.from(item['submitted_form'] as Map) : const {},
      requestCompany: item['request_company']?.toString() ?? '',
      documentValues: documentValues is List
          ? documentValues.whereType<Map>().map((raw) {
              final value = Map<String, dynamic>.from(raw);
              return WorkflowTaskDataValue(
                key: value['key']?.toString() ?? '',
                label: value['label']?.toString() ?? '',
                value: value['value'],
                fieldtype: value['fieldtype']?.toString(),
              );
            }).toList(growable: false)
          : const [],
      requestValues: item['request_values'] is Map
          ? Map<String, dynamic>.from(item['request_values'] as Map)
          : const {},
      supplementaryForm: item['supplementary_form'] is Map
          ? Map<String, dynamic>.from(item['supplementary_form'] as Map)
          : const {},
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
  Future<void> saveDraftWithSupplementary(
    String task,
    Map<String, dynamic> values, {
    required Map<String, dynamic> supplementaryValues,
  }) async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.save_workflow_task_draft',
      data: {
        'task': task,
        'response': values,
        if (supplementaryValues.isNotEmpty)
          'supplementary_values': supplementaryValues,
      },
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

/// One activity/history row of `get_workflow_instance` or `get_workflow_task`.
/// The additive keys (`actor_name`, `before`, `after`, `labels`) are parsed
/// defensively: an older server omits them and the row falls back to the raw
/// actor and no change lines.
WorkflowTaskActivity _activity(Map<dynamic, dynamic> raw) {
  final value = Map<String, dynamic>.from(raw);
  return WorkflowTaskActivity(
    actor: value['actor']?.toString() ?? '',
    action: value['action']?.toString() ?? '',
    comment: value['comment']?.toString() ?? '',
    createdOn: DateTime.tryParse(value['created_on']?.toString() ?? ''),
    stageTitle: value['stage_title']?.toString() ?? '',
    actorName: value['actor_name']?.toString() ?? '',
    before: value['before'] is Map
        ? Map<String, dynamic>.from(value['before'] as Map)
        : const {},
    after: value['after'] is Map
        ? Map<String, dynamic>.from(value['after'] as Map)
        : const {},
    labels: value['labels'] is Map
        ? {
            for (final entry in (value['labels'] as Map).entries)
              '${entry.key}': '${entry.value}'
          }
        : const {},
  );
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
      endOutcome: item['end_outcome']?.toString() ?? '',
    );
