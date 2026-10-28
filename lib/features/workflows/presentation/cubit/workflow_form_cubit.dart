import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/failure_message.dart';
import '../../data/workflow_template_repository.dart';

import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_form_state.dart';

class WorkflowFormCubit extends Cubit<WorkflowFormState> {
  WorkflowFormCubit({required this.repository, this.existing, this.templates})
      : super(const WorkflowFormState());
  final WorkflowRepository repository;
  final WorkflowDefinition? existing;
  final WorkflowTemplateRepository? templates;

  Future<void> load() async {
    emit(
        state.copyWith(status: WorkflowFormStatus.loading, clearMessage: true));
    try {
      final options = await repository.getFormOptions();
      if (isClosed) return;
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
      if (isClosed) return;
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
      emit(state.copyWith(company: value ?? '',
          clearTemplate: value != state.company));
  void changeCreationMode(String value) =>
      emit(state.copyWith(creationMode: value, clearTemplate: value != 'Template'));
  void selectTemplate(WorkflowTemplate value) {
    emit(state.copyWith(creationMode: 'Template', selectedTemplate: value,
      title: state.title.isEmpty || state.title == state.selectedTemplate?.title ? value.title : state.title,
      description: state.description.isEmpty || state.description == state.selectedTemplate?.description
          ? value.description : state.description,
      moduleKey: value.module, targetDoctype: value.targetDoctype,
      iconKey: value.icon, colorHex: value.color, clearMessage: true, clearTitleError: true));
  }
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
    if (state.title.trim().length < 3 || state.title.trim().length > 140) {
      emit(state.copyWith(titleError: 'عنوان فرایند باید بین ۳ تا ۱۴۰ نویسه باشد.'));
      return;
    }
    if (state.description.length > 2000) {
      emit(state.copyWith(message: 'توضیح گردش کار باید حداکثر ۲۰۰۰ نویسه باشد.'));
      return;
    }
    if (state.moduleKey.isEmpty || state.targetDoctype.isEmpty) {
      emit(state.copyWith(message: 'ماژول گردش کار را انتخاب کنید.'));
      return;
    }
    if (existing == null && state.creationMode == 'Template' &&
        (state.selectedTemplate == null || templates == null)) {
      emit(state.copyWith(message: 'ابتدا یک الگوی آماده را انتخاب کنید.'));
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
          : state.creationMode == 'Template'
          ? await templates!.copy(company: state.company, source: state.selectedTemplate!,
              title: state.title.trim(), description: state.description.trim(),
              icon: state.iconKey, color: state.colorHex)
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
      if (isClosed) return;
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
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        status: WorkflowFormStatus.failure,
        message: failureDetail(error),
      ));
    }
  }
}
