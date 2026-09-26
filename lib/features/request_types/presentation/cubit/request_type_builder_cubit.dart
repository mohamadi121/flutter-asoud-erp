import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/network/api_exception.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';

part 'request_type_builder_state.dart';

const requestTargetDoctype = 'ASOUD Workflow Request';

/// Builds a request type: a workflow on [requestTargetDoctype] whose first
/// user task after Start holds the request form.
class RequestTypeBuilderCubit extends Cubit<RequestTypeBuilderState> {
  RequestTypeBuilderCubit(
      {required this.repository, this.company, WorkflowDefinition? existing})
      : super(RequestTypeBuilderState(definition: existing));
  final WorkflowRepository repository;
  final String? company;

  Future<void> load() async {
    final existing = state.definition;
    if (existing != null) await _loadExisting(existing);
    await loadRoles();
  }

  Future<void> loadRoles() async {
    try {
      final options = await repository.getFormOptions();
      emit(state.copyWith(roles: options.roles));
    } catch (_) {
      // The access step shows the missing list and offers a retry.
    }
  }

  Future<void> _loadExisting(WorkflowDefinition existing) async {
    emit(state.copyWith(loading: true, clearMessage: true));
    try {
      final design = await repository.getDesign(existing.id);
      final workflow = design.workflow;
      final form = _formStage(design);
      final start = _startStage(design);
      emit(state.copyWith(
        loading: false,
        design: design,
        definition: workflow,
        active: workflow.status == WorkflowDefinitionStatus.active,
        info: RequestTypeInfo(
          title: workflow.title,
          shortTitle: workflow.shortTitle ?? '',
          description: workflow.description ?? '',
          category: workflow.category ?? 'General',
          iconKey: workflow.iconKey ?? 'other',
          colorHex: workflow.colorHex ?? '#71809B',
          showInList: workflow.showInList,
          userSubmittable: workflow.userSubmittable,
        ),
        fields: ((form?.config['form_fields'] as List?) ?? const [])
            .whereType<Map>()
            .map(WorkflowFormFieldDefinition.fromMap)
            .toList(),
        initiatorRoles:
            ((start?.config['initiator_roles'] as List?) ?? const [])
                .map((role) => role.toString())
                .toList(),
      ));
    } catch (error) {
      emit(state.copyWith(
          loading: false,
          message: _error(error, 'دریافت اطلاعات نوع درخواست ممکن نشد.')));
    }
  }

  void updateInfo(RequestTypeInfo info) => emit(state.copyWith(info: info));

  void setActive(bool value) => emit(state.copyWith(active: value));

  void setFields(List<WorkflowFormFieldDefinition> fields) =>
      emit(state.copyWith(fields: fields));

  void setInitiatorRoles(List<String> roles) =>
      emit(state.copyWith(initiatorRoles: roles));

  void back() {
    if (state.step > 0) {
      emit(state.copyWith(step: state.step - 1, clearMessage: true));
    }
  }

  /// Step 1: create the draft on first save, then store its metadata.
  Future<void> saveInfo() async {
    final info = state.info;
    if (info.title.trim().length < 3) {
      emit(state.copyWith(message: 'نام درخواست حداقل ۳ حرف باشد.'));
      return;
    }
    await _run('ذخیره اطلاعات کلی ممکن نشد.', () async {
      final draft = state.definition ??
          await repository.createDraft(
            title: info.title.trim(),
            moduleKey: 'Support',
            targetDoctype: requestTargetDoctype,
            creationMode: 'Custom',
            description: info.description,
            company: company,
            iconKey: info.iconKey,
            colorHex: info.colorHex,
          );
      final saved = await repository.saveRequestTypeInfo(
          definition: draft.id, info: info);
      emit(state.copyWith(definition: saved, step: 1));
    });
  }

  /// Step 2: store the custom fields on the first user task after Start,
  /// adding that task when the workflow has none.
  Future<void> saveForm() async {
    final definition = state.definition;
    if (definition == null) return;
    await _run('ذخیره فرم درخواست ممکن نشد.', () async {
      var design = await repository.getDesign(definition.id);
      var form = _formStage(design);
      if (form == null) {
        final start = _startStage(design)!;
        final next = design.transitions
            .where((edge) => edge.fromStage == start.id)
            .firstOrNull;
        design = next == null
            ? await repository.addStage(
                definition: definition.id,
                afterStage: start.id,
                type: WorkflowStageType.userTask)
            : await repository.insertStage(
                definition: definition.id,
                transition: next.id,
                type: WorkflowStageType.userTask);
        form = _formStage(design)!;
      }
      final config = form.config;
      design = await repository.saveStageSettings(
        definition: definition.id,
        stage: form.id,
        config: {
          ...config,
          'title': config.isEmpty ? 'تکمیل فرم درخواست' : form.title,
          'activity_type': config['activity_type'] ?? 'Data Entry',
          'assignment_type': config['assignment_type'] ?? 'Initiator',
          'form_fields': state.fields.map((field) => field.toMap()).toList(),
        },
      );
      emit(state.copyWith(design: design, step: 2));
    });
  }

  void continueToAccess() => emit(state.copyWith(step: 3, clearMessage: true));

  /// Step 4: who may submit, then the requested status.
  Future<void> saveAccess() async {
    final definition = state.definition;
    if (definition == null) return;
    if (state.initiatorRoles.isEmpty) {
      emit(state.copyWith(message: 'حداقل یک نقش مجاز انتخاب کنید.'));
      return;
    }
    await _run('ذخیره دسترسی‌ها ممکن نشد.', () async {
      final start = state.design == null ? null : _startStage(state.design!);
      final config = start?.config ?? const {};
      await repository.saveStartSettings(
        definition: definition.id,
        triggerType: config['trigger_type']?.toString() ?? 'Manual',
        initiatorRoles: state.initiatorRoles,
        subjectSource:
            config['subject_source']?.toString() ?? 'General Subject',
        passMode: config['pass_mode']?.toString() ?? 'Direct',
      );
      final isActive = definition.status == WorkflowDefinitionStatus.active;
      if (state.active == isActive) {
        emit(state.copyWith(completed: true));
        return;
      }
      try {
        await repository.setWorkflowStatus(
            definition: definition.id,
            status: state.active
                ? WorkflowDefinitionStatus.active
                : WorkflowDefinitionStatus.inactive);
        emit(state.copyWith(completed: true));
      } catch (_) {
        emit(state.copyWith(
            completed: true,
            message: 'ذخیره شد؛ فعال‌سازی پس از تکمیل گردش کار ممکن است.'));
      }
    });
  }

  Future<void> _run(String failure, Future<void> Function() action) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, clearMessage: true));
    try {
      await action();
    } catch (error) {
      emit(state.copyWith(message: _error(error, failure)));
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  String _error(Object error, String fallback) =>
      error is ApiException && error.message.isNotEmpty
          ? error.message
          : fallback;
}

WorkflowStage? _startStage(WorkflowDesign design) => design.stages
    .where((stage) => stage.type == WorkflowStageType.start)
    .firstOrNull;

/// The user task directly after Start: the request runtime reads its form.
WorkflowStage? _formStage(WorkflowDesign design) {
  final start = _startStage(design);
  if (start == null) return null;
  for (final edge in design.transitions) {
    if (edge.fromStage != start.id) continue;
    final stage =
        design.stages.where((item) => item.id == edge.toStage).firstOrNull;
    if (stage?.type == WorkflowStageType.userTask) return stage;
  }
  return null;
}
