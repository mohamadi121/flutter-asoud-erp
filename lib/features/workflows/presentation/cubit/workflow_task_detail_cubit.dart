import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/network/frappe_client.dart';
import '../../data/workflow_action_repository.dart';

import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../../domain/repositories/workflow_task_supplementary_repository.dart';

enum WorkflowTaskDetailStatus { loading, ready, saving, success, failure }

class WorkflowTaskDetailState extends Equatable {
  const WorkflowTaskDetailState({
    this.status = WorkflowTaskDetailStatus.loading,
    this.detail,
    this.values = const {},
    this.supplementaryValues = const {},
    this.message,
    this.offline = false,
    this.failure,
  });
  final WorkflowTaskDetailStatus status;
  final WorkflowTaskDetail? detail;
  final Map<String, dynamic> values;

  /// The approval stage's supplementary form values, kept apart from the
  /// decision `values` (contract C6).
  final Map<String, dynamic> supplementaryValues;
  final String? message;
  final bool offline;
  final Object? failure;
  @override
  List<Object?> get props =>
      [status, detail, values, supplementaryValues, message, offline, failure];
}

class WorkflowTaskDetailCubit extends Cubit<WorkflowTaskDetailState> {
  WorkflowTaskDetailCubit(this._repository, this.task, {this.actionClient})
      : super(const WorkflowTaskDetailState());
  final WorkflowTaskRepository _repository;
  final String task;
  final FrappeApiClient? actionClient;
  WorkflowActionRepository get _action => WorkflowActionRepository(actionClient!, state.detail!.actionCompany, task,
    uploads: state.detail!.allowAddAttachments);

  void setValues(Map<String, dynamic> values) => emit(WorkflowTaskDetailState(
    status: WorkflowTaskDetailStatus.ready, detail: state.detail, values: values,
    supplementaryValues: state.supplementaryValues, offline: state.offline));

  void setSupplementaryValues(Map<String, dynamic> values) => emit(WorkflowTaskDetailState(
    status: WorkflowTaskDetailStatus.ready, detail: state.detail, values: state.values,
    supplementaryValues: values, offline: state.offline));

  /// True when the task's stage has a supplementary form binding.
  bool get _hasSupplementaryForm =>
      state.detail?.supplementaryForm.isNotEmpty == true;

  /// The repository that can send the supplementary values, if any.
  WorkflowTaskSupplementaryRepository? get _supplementaryRepository =>
      _hasSupplementaryForm
          ? _repository is WorkflowTaskSupplementaryRepository
              ? _repository as WorkflowTaskSupplementaryRepository
              : null
          : null;

  Future<bool> performAction(String action) async {
    if (state.status == WorkflowTaskDetailStatus.saving) return false;
    if (actionClient == null || state.offline || !actionClient!.isAuthenticated) {
      _failure(StateError('ثبت اقدام نیازمند ارتباط واقعی با سرور است.')); return false;
    }
    emit(WorkflowTaskDetailState(status: WorkflowTaskDetailStatus.saving, detail: state.detail,
      values: state.values, offline: state.offline));
    try {
      await _action.perform(action, state.values);
      if (isClosed) return false;
      if (action == 'Complete') {
        emit(WorkflowTaskDetailState(status: WorkflowTaskDetailStatus.success, detail: state.detail,
          values: state.values, message: 'اقدام ثبت و تکمیل شد.')); return true;
      }
      await load();
      if (isClosed || state.status == WorkflowTaskDetailStatus.failure) return false;
      emit(WorkflowTaskDetailState(status: WorkflowTaskDetailStatus.ready, detail: state.detail, values: state.values,
        message: action == 'Claim' ? 'اقدام دریافت شد.' : 'وضعیت اقدام ثبت شد؛ گردش کار در همین مرحله باقی ماند.'));
      return true;
    } catch (error) { if (!isClosed) _failure(error); return false; }
  }

  Future<void> load() async {
    emit(const WorkflowTaskDetailState());
    try {
      final detail = await _repository.getTask(task);
      if (isClosed) return;
      final rawSupplementary = detail.supplementaryForm['values'];
      emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.ready,
        detail: detail,
        values: detail.values,
        supplementaryValues: rawSupplementary is Map
            ? Map<String, dynamic>.from(rawSupplementary)
            : const {},
        offline: _repository.isOfflinePreview,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.failure, message: failureDetail(error), failure: error));
    }
  }

  Future<bool> reassign(String user) async {
    if (state.status == WorkflowTaskDetailStatus.saving) return false;
    if (state.detail?.allowReassign != true || state.detail?.task.status != 'Open' || state.detail?.requiresClaim == true ||
        actionClient == null || !actionClient!.isAuthenticated || state.offline) {
      _failure(StateError('واگذاری این اقدام در وضعیت فعلی مجاز نیست.'));
      return false;
    }
    emit(WorkflowTaskDetailState(status: WorkflowTaskDetailStatus.saving, detail: state.detail, values: state.values));
    try {
      await _action.reassign(user);
      if (isClosed) return false;
      emit(WorkflowTaskDetailState(status: WorkflowTaskDetailStatus.success, detail: state.detail,
          values: state.values, message: 'وظیفه به مسئول جدید واگذار شد.'));
      return true;
    } catch (error) {
      if (!isClosed) _failure(error);
      return false;
    }
  }

  void setValue(String key, dynamic value) => emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.ready,
        detail: state.detail,
        values: {...state.values, key: value},
        supplementaryValues: state.supplementaryValues,
        offline: state.offline,
      ));

  String? validate() {
    final detail = state.detail;
    if (detail == null) return 'فرم مرحله دریافت نشده است.';
    for (final field in detail.fields.where((field) => field.required)) {
      final value = state.values[field.key];
      if (value == null || value == '' || (value is List && value.isEmpty)) {
        return 'فیلد «${field.label}» الزامی است.';
      }
    }
    num? number(Object? value) {
      if (value is num) return value;
      return num.tryParse((value ?? '').toString().replaceAll(',', ''));
    }
    for (final field in detail.fields) {
      final value = number(state.values[field.key]);
      if (value != null && field.minValueExclusive != null &&
          value <= field.minValueExclusive!) {
        return 'مقدار «${field.label}» باید بیشتر از ${field.minValueExclusive} باشد.';
      }
      final maximum = number(detail.requestValues[field.maxFromRequest]);
      if (value != null && maximum != null && value > maximum) {
        return 'مقدار «${field.label}» نباید از مقدار درخواست‌شده بیشتر باشد.';
      }
      final comparison = number(detail.requestValues[field.reasonRequiredIfLessThan]);
      if (value != null && comparison != null && value < comparison) {
        final reason = state.values[field.reasonField]?.toString().trim() ?? '';
        if (reason.isEmpty) return 'ثبت علت کاهش الزامی است.';
      }
      if (field.rowsFromRequest == null) continue;
      final rows = state.values[field.key];
      final requestRows = detail.requestValues[field.rowsFromRequest];
      if (rows is! List || requestRows is! List || rows.length != requestRows.length) {
        return 'تعداد ردیف‌های «${field.label}» نباید تغییر کند.';
      }
      for (var index = 0; index < rows.length; index++) {
        if (rows[index] is! Map || requestRows[index] is! Map) continue;
        for (final column in field.columns) {
          final rowValue = number((rows[index] as Map)[column.key]);
          final rowMaximum = number((requestRows[index] as Map)[column.maxFromRow]);
          if (rowValue != null && rowMaximum != null && rowValue > rowMaximum) {
            return 'مقدار «${column.label}» در ردیف ${index + 1} نباید از مقدار درخواست‌شده بیشتر باشد.';
          }
        }
      }
    }
    return null;
  }

  /// A supplementary form the repository cannot send must not be dropped
  /// silently; the decision or draft is blocked until it can be sent.
  bool get _supplementaryBlocked =>
      _hasSupplementaryForm &&
      _supplementaryRepository == null &&
      state.supplementaryValues.isNotEmpty;

  void _supplementaryUnsupported() {
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.failure,
        detail: state.detail,
        values: state.values,
        supplementaryValues: state.supplementaryValues,
        offline: state.offline,
        message: 'این نسخه از برنامه امکان ثبت فرم تکمیلی را ندارد.'));
  }

  Future<bool> saveDraft() async {
    if (state.status == WorkflowTaskDetailStatus.saving) return false;
    if (_supplementaryBlocked) {
      _supplementaryUnsupported();
      return false;
    }
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        supplementaryValues: state.supplementaryValues,
        offline: state.offline));
    try {
      if (state.detail?.actionSchema.isNotEmpty == true) {
        if (actionClient == null || !actionClient!.isAuthenticated || state.offline) throw StateError('ذخیرهٔ پیش‌نویس اقدام به ارتباط با سرور نیاز دارد.');
        await _action.draft(state.values);
      } else {
        final supplementary = _supplementaryRepository;
        if (supplementary != null) {
          await supplementary.saveDraftWithSupplementary(task, state.values,
              supplementaryValues: state.supplementaryValues);
        } else { await _repository.saveDraft(task, state.values); }
      }
      if (isClosed) return false;
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.ready,
          detail: state.detail,
          values: state.values,
          supplementaryValues: state.supplementaryValues,
          offline: _repository.isOfflinePreview,
          message: _repository.isOfflinePreview
              ? 'پیش‌نویس داخل گوشی ذخیره شد.'
              : 'پیش‌نویس ذخیره شد.'));
      return true;
    } catch (error) {
      _failure(error);
      return false;
    }
  }

  Future<void> setAttachment(
      String key, String filename, List<int> bytes) async {
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        offline: state.offline));
    try {
      final url = await _repository.uploadAttachment(
          task: task, filename: filename, bytes: bytes);
      setValue(key, url);
    } catch (error) {
      _failure(error);
    }
  }

  Future<String?> uploadTableAttachment(
      String filename, List<int> bytes) async {
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        offline: state.offline));
    try {
      final url = await _repository.uploadAttachment(
          task: task, filename: filename, bytes: bytes);
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.ready,
          detail: state.detail,
          values: state.values,
          offline: state.offline));
      return url;
    } catch (error) {
      _failure(error);
      return null;
    }
  }

  Future<bool> submit(String action, {String? comment}) async {
    final error = validate();
    if ({'Complete', 'Approve'}.contains(action) && error != null) {
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.failure,
          detail: state.detail,
          values: state.values,
          offline: state.offline,
          message: error));
      return false;
    }
    if (_supplementaryBlocked) {
      _supplementaryUnsupported();
      return false;
    }
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        supplementaryValues: state.supplementaryValues,
        offline: state.offline));
    try {
      final supplementary = _supplementaryRepository;
      if (supplementary != null) {
        await supplementary.completeTaskWithSupplementary(
            task: task,
            action: action,
            comment: comment,
            response: state.values,
            supplementaryValues: state.supplementaryValues);
      } else {
        await _repository.completeTask(
            task: task, action: action, comment: comment, response: state.values);
      }
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.success,
          detail: state.detail,
          values: state.values,
          supplementaryValues: state.supplementaryValues,
          offline: _repository.isOfflinePreview,
          message: _repository.isOfflinePreview
              ? 'اقدام محلی ثبت شد و هنوز به سرور ارسال نشده است.'
              : 'اقدام با موفقیت ثبت شد.'));
      return true;
    } catch (error) {
      _failure(error);
      return false;
    }
  }

  void _failure(Object error) {
    if (isClosed) return;
    emit(WorkflowTaskDetailState(
      status: WorkflowTaskDetailStatus.failure,
      detail: state.detail,
      values: state.values,
      supplementaryValues: state.supplementaryValues,
      offline: state.offline,
      message: failureDetail(error), failure: error));
  }
}
