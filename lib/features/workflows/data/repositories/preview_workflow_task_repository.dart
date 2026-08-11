import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

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
      'current_task': 'initial',
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

  WorkflowTask _offlineTask(String status, {String current = 'initial'}) =>
      WorkflowTask(
        id: switch (current) {
          'urgent' => 'WFT-OFFLINE-URGENT',
          'normal' => 'WFT-OFFLINE-NORMAL',
          'correction' => 'WFT-OFFLINE-CORRECTION',
          _ => 'WFT-OFFLINE-001',
        },
        instance: 'WFI-OFFLINE-001',
        stage: switch (current) {
          'urgent' => 'STAGE-OFFLINE-URGENT-APPROVAL',
          'normal' => 'STAGE-OFFLINE-NORMAL-REVIEW',
          'correction' => 'STAGE-OFFLINE-CORRECTION',
          _ => 'STAGE-OFFLINE-DATA-ENTRY',
        },
        title: switch (current) {
          'urgent' => 'تأیید فوری مدیر',
          'normal' => 'بررسی عادی درخواست',
          'correction' => 'اصلاح درخواست خرید',
          _ => 'ثبت درخواست خرید',
        },
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
      final currentTask = saved['current_task']?.toString() ?? 'initial';
      return current == status
          ? [_offlineTask(current, current: currentTask)]
          : const [];
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
    final current = saved['current_task']?.toString() ?? 'initial';
    final initial = current == 'initial' || current == 'correction';
    final previousData = !initial && draft is Map && draft.isNotEmpty
        ? [
            WorkflowTaskDataSection(
              title: 'اطلاعات درخواست ثبت‌شده',
              values: Map<String, dynamic>.from(draft)
                  .entries
                  .where((entry) => entry.key != 'confirmed')
                  .map((entry) => WorkflowTaskDataValue(
                        key: entry.key,
                        label: switch (entry.key) {
                          'request_title' => 'عنوان درخواست',
                          'description' => 'توضیحات',
                          'amount' => 'مبلغ برآوردی',
                          'priority' => 'اولویت',
                          _ => entry.key,
                        },
                        value: entry.value,
                      ))
                  .toList(growable: false),
            ),
          ]
        : const <WorkflowTaskDataSection>[];
    return WorkflowTaskDetail(
      task:
          _offlineTask(saved['status']?.toString() ?? 'Open', current: current),
      stageType: current == 'urgent' ? 'Approval' : 'User Task',
      fields: initial
          ? const [
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
            ]
          : const [],
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
      allowReject: current == 'urgent',
      allowReturn: current == 'urgent' || current == 'normal',
      commentRequired: current == 'urgent',
      activityType: current == 'normal' ? 'Review' : '',
      previousData: previousData,
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
    final root = await getApplicationSupportDirectory();
    final directory =
        Directory('${root.path}${Platform.pathSeparator}workflow_attachments');
    await directory.create(recursive: true);
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File(
        '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName');
    await file.writeAsBytes(bytes, flush: true);
    attachments[filename] = file.path;
    saved['attachments'] = attachments;
    await _write(saved);
    return 'local://${file.path}';
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
    if (response.isNotEmpty) saved['draft'] = response;
    final history = saved['history'] is List
        ? List<dynamic>.from(saved['history'] as List)
        : <dynamic>[];
    history.add({
      'actor': 'کاربر محلی',
      'action': action,
      'comment': comment ?? '',
      'created_on': DateTime.now().toIso8601String(),
    });
    final current = saved['current_task']?.toString() ?? 'initial';
    if ((current == 'initial' || current == 'correction') &&
        action == 'Complete') {
      final urgent = response['priority'] == 'فوری';
      saved['current_task'] = urgent ? 'urgent' : 'normal';
      saved['status'] = 'Open';
      history.add({
        'actor': 'موتور گردش‌کار محلی',
        'action': urgent ? 'Condition True' : 'Condition False',
        'comment': urgent
            ? 'اولویت فوری است؛ ارجاع به تأیید فوری مدیر.'
            : 'اولویت فوری نیست؛ ارجاع به بررسی عادی.',
        'created_on': DateTime.now().toIso8601String(),
      });
    } else if (action == 'Return') {
      if (comment?.trim().isEmpty ?? true) {
        throw StateError('علت بازگشت برای اصلاح الزامی است.');
      }
      saved['current_task'] = 'correction';
      saved['status'] = 'Open';
    } else {
      saved['status'] = action == 'Reject' ? 'Rejected' : 'Completed';
    }
    saved['history'] = history;
    await _write(saved);
  }
}
