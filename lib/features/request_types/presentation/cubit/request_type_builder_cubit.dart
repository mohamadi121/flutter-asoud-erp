import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/failure_message.dart';
import '../../domain/request_templates.dart';
import '../../domain/request_form_layout.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';

part 'request_type_builder_state.dart';

const requestTargetDoctype = 'ASOUD Workflow Request';

/// Builds a request type: a workflow on [requestTargetDoctype] whose first
/// user task after Start holds the request form.
class RequestTypeBuilderCubit extends Cubit<RequestTypeBuilderState> {
  RequestTypeBuilderCubit(
      {required this.repository,
      this.company,
      WorkflowDefinition? existing,
      RequestTemplate? template})
      : super(RequestTypeBuilderState(
            definition: existing,
            info: existing == null && template != null
                ? template.info
                : const RequestTypeInfo(title: ''),
            fields: existing == null && template != null
                ? List.of(template.fields)
                : const [],
            active: false));
  final WorkflowRepository repository;
  final String? company;

  Future<void> load() async {
    final existing = state.definition;
    if (existing != null) await _loadExisting(existing);
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
          colorHex: workflow.colorHex ?? '#5B6478',
          showInList: workflow.showInList,
          userSubmittable: workflow.userSubmittable,
        ),
        fields: ((form?.config['form_fields'] as List?) ?? const [])
            .whereType<Map>()
            .map(WorkflowFormFieldDefinition.fromMap)
            .toList(),
        layout: normalizeRequestLayout(
            ((form?.config['form_fields'] as List?) ?? const [])
                .whereType<Map>()
                .map(WorkflowFormFieldDefinition.fromMap)
                .toList(),
            form?.config['form_layout'] as List? ?? const []),
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

  void setFields(List<WorkflowFormFieldDefinition> fields,
      {bool reorderLayout = false}) {
    var placements = normalizeRequestLayout(
        fields, state.layout.map((item) => item.toMap()));
    if (reorderLayout) {
      final byKey = {
        for (final placement in placements) placement.key: placement
      };
      var index = 0;
      placements = [
        for (final placement in placements)
          requestBaseLayout.containsKey(placement.key)
              ? placement
              : byKey[fields[index++].key]!,
      ];
    }
    emit(state.copyWith(fields: fields, layout: placements));
  }

  List<RequestFieldPlacement> get layout => normalizeRequestLayout(
      state.fields, state.layout.map((item) => item.toMap()));

  void moveField(String source, String target) {
    if (state.saving || source == target) return;
    final items = layout;
    final from = items.indexWhere((item) => item.key == source);
    final to = items.indexWhere((item) => item.key == target);
    if (from < 0 || to < 0) return;
    items.insert(to, items.removeAt(from));
    emit(state.copyWith(layout: items));
  }

  void resizeField(String key) {
    if (state.saving) return;
    emit(state.copyWith(layout: [
      for (final item in layout)
        item.key == key
            ? RequestFieldPlacement(key, fullWidth: !item.fullWidth)
            : item,
    ]));
  }

  void setInitiatorRoles(List<String> roles) =>
      emit(state.copyWith(initiatorRoles: roles));

  void back() {
    if (state.step > 0) {
      emit(state.copyWith(step: state.step - 1, clearMessage: true));
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step < state.step) {
      emit(state.copyWith(step: step, clearMessage: true));
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
    if (definition == null) {
      _showMessage('ابتدا بخش «اطلاعات کلی» را تکمیل کنید.');
      return;
    }
    if (definition.isSystemTemplate) {
      emit(state.copyWith(step: 2, clearMessage: true));
      return;
    }
    final validation = _formValidationMessage();
    if (validation != null) {
      _showMessage(validation);
      return;
    }
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
          'form_layout': layout.map((item) => item.toMap()).toList(),
        },
      );
      emit(state.copyWith(design: design, step: 2));
    });
  }

  String? _formValidationMessage() {
    for (var index = 0; index < state.fields.length; index++) {
      final field = state.fields[index];
      final name = field.label.trim().isNotEmpty
          ? field.label.trim()
          : field.key.trim().isNotEmpty
              ? field.key.trim()
              : 'شماره ${index + 1}';
      if (field.label.trim().isEmpty) {
        return 'عنوان فیلد «$name» وارد نشده است.';
      }
      if (field.key.trim().isEmpty) {
        return 'شناسه فیلد «$name» وارد نشده است.';
      }
      if (field.type.trim().isEmpty) {
        return 'نوع فیلد «$name» انتخاب نشده است.';
      }
      if (field.type == 'Choice' && field.options.length < 2) {
        return 'گزینه‌های فیلد «$name» کامل نیست؛ حداقل دو گزینه وارد کنید.';
      }
    }
    return null;
  }

  void _showMessage(String message) {
    emit(state.copyWith(clearMessage: true));
    emit(state.copyWith(message: message));
  }

  void continueToAccess() => emit(state.copyWith(step: 3, clearMessage: true));

  /// Save presentation without changing initiator roles or granting access.
  Future<void> finish() async {
    final definition = state.definition;
    if (definition?.isSystemTemplate == true) {
      emit(state.copyWith(completed: true));
      return;
    }
    final form = state.design == null ? null : _formStage(state.design!);
    if (definition == null || form == null) return;
    await _run('ذخیره چیدمان ممکن نشد.', () async {
      final design = await repository.saveStageSettings(
          definition: definition.id,
          stage: form.id,
          config: {
            ...form.config,
            'form_fields': state.fields.map((field) => field.toMap()).toList(),
            'form_layout': layout.map((item) => item.toMap()).toList(),
          });
      emit(state.copyWith(design: design, completed: true));
    });
  }

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
      error is ApiException ? failureMessage(error) : fallback;
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
