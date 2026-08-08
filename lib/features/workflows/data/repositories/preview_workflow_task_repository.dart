import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

class PreviewWorkflowTaskRepository implements WorkflowTaskRepository {
  PreviewWorkflowTaskRepository(this._remote);
  static const _storageKey = 'asoud_workflow_offline_tasks_v1';
  final WorkflowTaskRepository _remote;
  bool _offline = false;

  @override
  bool get isOfflinePreview => _offline;

  bool _networkFailure(Object error) =>
      error is ApiException &&
      (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout);

  Future<Map<String, dynamic>> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw != null) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final seed = <String, dynamic>{
      'status': 'Open',
      'draft': <String, dynamic>{},
      'history': <dynamic>[],
      'attachments': <String, dynamic>{},
    };
    await preferences.setString(_storageKey, jsonEncode(seed));
    return seed;
  }

  Future<void> _write(Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(value));
  }

  WorkflowTask _offlineTask(String status) => WorkflowTask(
        id: 'WFT-OFFLINE-001',
        instance: 'WFI-OFFLINE-001',
        stage: 'STAGE-OFFLINE-REVIEW',
        title: 'بررسی درخواست خرید',
        status: status,
        assignedOn: DateTime(2026, 8, 9, 9, 30),
        localOnly: true,
      );

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async {
    try {
      final result = await _remote.getMyTasks(status: status);
      _offline = false;
      return result;
    } catch (error) {
      if (!_networkFailure(error)) rethrow;
      _offline = true;
      final saved = await _read();
      final current = saved['status']?.toString() ?? 'Open';
      return current == status ? [_offlineTask(current)] : const [];
    }
  }

  @override
  Future<WorkflowTaskDetail> getTask(String task) async {
    if (!_offline) {
      try {
        return await _remote.getTask(task);
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _offline = true;
      }
    }
    final saved = await _read();
    final draft = saved['draft'];
    final history = saved['history'];
    return WorkflowTaskDetail(
      task: _offlineTask(saved['status']?.toString() ?? 'Open'),
      stageType: 'User Task',
      fields: const [
        WorkflowFormFieldDefinition(
            key: 'request_title',
            label: 'عنوان درخواست',
            type: 'Short Text',
            required: true),
        WorkflowFormFieldDefinition(
            key: 'description', label: 'توضیحات', type: 'Long Text'),
        WorkflowFormFieldDefinition(
            key: 'amount', label: 'مبلغ برآوردی', type: 'Currency'),
        WorkflowFormFieldDefinition(
            key: 'priority',
            label: 'اولویت',
            type: 'Choice',
            options: ['عادی', 'فوری']),
        WorkflowFormFieldDefinition(
            key: 'attachment', label: 'پیوست', type: 'Attachment'),
        WorkflowFormFieldDefinition(
            key: 'confirmed',
            label: 'اطلاعات را تأیید می‌کنم',
            type: 'Checkbox',
            required: true),
      ],
      values: draft is Map ? Map<String, dynamic>.from(draft) : const {},
      activities: history is List
          ? history.whereType<Map>().map((raw) {
              final item = Map<String, dynamic>.from(raw);
              return WorkflowTaskActivity(
                actor: item['actor']?.toString() ?? 'کاربر محلی',
                action: item['action']?.toString() ?? '',
                comment: item['comment']?.toString() ?? '',
                createdOn:
                    DateTime.tryParse(item['created_on']?.toString() ?? ''),
              );
            }).toList(growable: false)
          : const [],
      allowReject: true,
      allowReturn: true,
    );
  }

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {
    if (!_offline) {
      try {
        await _remote.saveDraft(task, values);
        return;
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _offline = true;
      }
    }
    final saved = await _read();
    saved['draft'] = values;
    await _write(saved);
  }

  @override
  Future<String> uploadAttachment({
    required String task,
    required String filename,
    required List<int> bytes,
  }) async {
    if (!_offline) {
      try {
        return await _remote.uploadAttachment(
            task: task, filename: filename, bytes: bytes);
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _offline = true;
      }
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('حجم فایل نباید بیشتر از ۱۰ مگابایت باشد.');
    }
    final saved = await _read();
    final attachments = saved['attachments'] is Map
        ? Map<String, dynamic>.from(saved['attachments'] as Map)
        : <String, dynamic>{};
    attachments[filename] = base64Encode(bytes);
    saved['attachments'] = attachments;
    await _write(saved);
    return 'local://$filename';
  }

  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) async {
    if (!_offline) {
      try {
        await _remote.completeTask(
          task: task,
          action: action,
          comment: comment,
          response: response,
        );
        return;
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _offline = true;
      }
    }
    final saved = await _read();
    saved['status'] = action == 'Reject' ? 'Rejected' : 'Completed';
    saved['draft'] = response;
    final history = saved['history'] is List
        ? List<dynamic>.from(saved['history'] as List)
        : <dynamic>[];
    history.add({
      'actor': 'کاربر محلی',
      'action': action,
      'comment': comment ?? '',
      'created_on': DateTime.now().toIso8601String(),
    });
    saved['history'] = history;
    await _write(saved);
  }
}
