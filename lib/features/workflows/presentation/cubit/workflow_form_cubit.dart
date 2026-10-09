import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_form_state.dart';

class WorkflowFormCubit extends Cubit<WorkflowFormState> {
  WorkflowFormCubit({required this.repository, this.existing})
      : super(const WorkflowFormState());
  final WorkflowRepository repository;
  final WorkflowDefinition? existing;

  Future<void> load() async {
    emit(
        state.copyWith(status: WorkflowFormStatus.loading, clearMessage: true));
    try {
      final options = await repository.getFormOptions();
      final firstModule = options.modules.firstOrNull;
      emit(state.copyWith(
        status: WorkflowFormStatus.ready,
        options: options,
        company: existing?.company ?? options.companies.firstOrNull ?? '',
        moduleKey: existing?.moduleKey ?? firstModule?.key ?? '',
        targetDoctype: existing?.targetDoctype ?? 'ASOUD Workflow Request',
        title: existing?.title ?? '',
        description: existing?.description ?? '',
        iconKey: existing?.iconKey ?? 'hub',
        colorHex: existing?.colorHex ?? '#315CF5',
        creationMode: existing?.creationMode ?? 'Custom',
        offlinePreview: repository is OfflinePreviewAware &&
            (repository as OfflinePreviewAware).isOfflinePreview,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowFormStatus.failure,
        message: 'دریافت گزینه‌های فرم از ASOUD ERP ممکن نشد.',
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
    emit(state.copyWith(moduleKey: key));
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
      emit(state.copyWith(message: 'ماژول گردش کار را انتخاب کنید.'));
      return;
    }
    emit(state.copyWith(
        status: WorkflowFormStatus.submitting, clearMessage: true));
    try {
      final old = existing;
      final draft = old != null
          ? await repository.saveRequestTypeInfo(
              definition: old.id,
              info: RequestTypeInfo(
                title: state.title.trim(),
                description: state.description.trim(),
                moduleKey: state.moduleKey,
                iconKey: state.iconKey,
                colorHex: state.colorHex,
                shortTitle: old.shortTitle ?? '',
                category: old.category ?? '',
                showInList: old.showInList,
                userSubmittable: old.userSubmittable,
              ),
            )
          : await repository.createDraft(
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
            ? 'اطلاعات روی دستگاه ذخیره شد؛ همگام‌سازی با سرور تأیید نشده است.'
            : 'اطلاعات گردش کار ذخیره شد.',
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowFormStatus.failure,
        message: 'ذخیره پیش‌نویس در ASOUD ERP ممکن نشد.',
      ));
    }
  }
}
