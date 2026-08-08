import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_form_state.dart';

class WorkflowFormCubit extends Cubit<WorkflowFormState> {
  WorkflowFormCubit({required this.repository})
      : super(const WorkflowFormState());
  final WorkflowRepository repository;

  Future<void> load() async {
    emit(
        state.copyWith(status: WorkflowFormStatus.loading, clearMessage: true));
    try {
      final options = await repository.getFormOptions();
      final firstModule = options.modules.firstOrNull;
      final firstDoctype =
          firstModule?.doctypes.where((item) => item.available).firstOrNull;
      emit(state.copyWith(
        status: WorkflowFormStatus.ready,
        options: options,
        company: options.companies.firstOrNull ?? '',
        moduleKey: firstModule?.key ?? '',
        targetDoctype: firstDoctype?.name ?? '',
        offlinePreview: repository is OfflinePreviewAware &&
            (repository as OfflinePreviewAware).isOfflinePreview,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowFormStatus.failure,
        message: 'دریافت گزینه‌های فرم از ERPNext ممکن نشد.',
      ));
    }
  }

  void changeTitle(String value) =>
      emit(state.copyWith(title: value, clearTitleError: true));
  void changeDescription(String value) =>
      emit(state.copyWith(description: value));
  void changeCompany(String? value) =>
      emit(state.copyWith(company: value ?? ''));
  void changeCreationMode(String value) =>
      emit(state.copyWith(creationMode: value));
  void changeIcon(String value) => emit(state.copyWith(iconKey: value));
  void changeColor(String value) => emit(state.copyWith(colorHex: value));

  void changeModule(String? value) {
    final key = value ?? '';
    final module =
        state.options?.modules.where((item) => item.key == key).firstOrNull;
    final doctype =
        module?.doctypes.where((item) => item.available).firstOrNull;
    emit(state.copyWith(moduleKey: key, targetDoctype: doctype?.name ?? ''));
  }

  void changeDoctype(String? value) =>
      emit(state.copyWith(targetDoctype: value ?? ''));

  Future<void> submit() async {
    if (state.status == WorkflowFormStatus.submitting) return;
    if (state.title.trim().length < 3) {
      emit(state.copyWith(titleError: 'عنوان فرایند باید حداقل ۳ نویسه باشد.'));
      return;
    }
    if (state.moduleKey.isEmpty || state.targetDoctype.isEmpty) {
      emit(state.copyWith(message: 'ماژول و نوع سند مقصد را انتخاب کنید.'));
      return;
    }
    emit(state.copyWith(
        status: WorkflowFormStatus.submitting, clearMessage: true));
    try {
      final draft = await repository.createDraft(
        title: state.title.trim(),
        description: state.description.trim(),
        company: state.company,
        moduleKey: state.moduleKey,
        targetDoctype: state.targetDoctype,
        creationMode: state.creationMode,
        iconKey: state.iconKey,
        colorHex: state.colorHex,
      );
      emit(state.copyWith(
        status: WorkflowFormStatus.success,
        createdDraft: draft,
        offlinePreview: repository is OfflinePreviewAware &&
            (repository as OfflinePreviewAware).isOfflinePreview,
        message: repository is OfflinePreviewAware &&
                (repository as OfflinePreviewAware).isOfflinePreview
            ? 'پیش‌نمایش محلی ایجاد شد؛ در ERPNext ذخیره نشده است.'
            : 'پیش‌نویس فرایند ایجاد شد.',
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowFormStatus.failure,
        message: 'ذخیره پیش‌نویس در ERPNext ممکن نشد.',
      ));
    }
  }
}
