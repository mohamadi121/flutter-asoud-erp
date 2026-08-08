import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';

enum WorkflowTaskDetailStatus { loading, ready, saving, success, failure }

class WorkflowTaskDetailState extends Equatable {
  const WorkflowTaskDetailState({
    this.status = WorkflowTaskDetailStatus.loading,
    this.detail,
    this.values = const {},
    this.message,
    this.offline = false,
  });
  final WorkflowTaskDetailStatus status;
  final WorkflowTaskDetail? detail;
  final Map<String, dynamic> values;
  final String? message;
  final bool offline;
  @override
  List<Object?> get props => [status, detail, values, message, offline];
}

class WorkflowTaskDetailCubit extends Cubit<WorkflowTaskDetailState> {
  WorkflowTaskDetailCubit(this._repository, this.task)
      : super(const WorkflowTaskDetailState());
  final WorkflowTaskRepository _repository;
  final String task;

  Future<void> load() async {
    emit(const WorkflowTaskDetailState());
    try {
      final detail = await _repository.getTask(task);
      emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.ready,
        detail: detail,
        values: detail.values,
        offline: _repository.isOfflinePreview,
      ));
    } catch (error) {
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.failure, message: error.toString()));
    }
  }

  void setValue(String key, dynamic value) => emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.ready,
        detail: state.detail,
        values: {...state.values, key: value},
        offline: state.offline,
      ));

  String? validate() {
    final detail = state.detail;
    if (detail == null) return 'فرم مرحله دریافت نشده است.';
    for (final field in detail.fields.where((field) => field.required)) {
      final value = state.values[field.key];
      if (value == null || value == '' || value == false) {
        return 'فیلد «${field.label}» الزامی است.';
      }
    }
    return null;
  }

  Future<bool> saveDraft() async {
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        offline: state.offline));
    try {
      await _repository.saveDraft(task, state.values);
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.ready,
          detail: state.detail,
          values: state.values,
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

  Future<bool> submit(String action, {String? comment}) async {
    final error = validate();
    if (action != 'Reject' && error != null) {
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.failure,
          detail: state.detail,
          values: state.values,
          offline: state.offline,
          message: error));
      return false;
    }
    emit(WorkflowTaskDetailState(
        status: WorkflowTaskDetailStatus.saving,
        detail: state.detail,
        values: state.values,
        offline: state.offline));
    try {
      await _repository.completeTask(
          task: task, action: action, comment: comment, response: state.values);
      emit(WorkflowTaskDetailState(
          status: WorkflowTaskDetailStatus.success,
          detail: state.detail,
          values: state.values,
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

  void _failure(Object error) => emit(WorkflowTaskDetailState(
      status: WorkflowTaskDetailStatus.failure,
      detail: state.detail,
      values: state.values,
      offline: state.offline,
      message: error.toString()));
}
