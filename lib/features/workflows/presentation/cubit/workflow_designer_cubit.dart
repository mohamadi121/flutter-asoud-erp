import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_designer_state.dart';

class WorkflowDesignerCubit extends Cubit<WorkflowDesignerState> {
  WorkflowDesignerCubit({required this.repository, required this.definition})
      : super(const WorkflowDesignerState());
  final WorkflowRepository repository;
  final String definition;

  Future<void> load() async {
    emit(state.copyWith(
        status: WorkflowDesignerStatus.loading, clearMessage: true));
    try {
      final design = await repository.getDesign(definition);
      final options = await repository.getFormOptions();
      emit(state.copyWith(
          status: WorkflowDesignerStatus.ready,
          design: design,
          options: options,
          offlinePreview: repository is OfflinePreviewAware &&
              (repository as OfflinePreviewAware).isOfflinePreview));
    } catch (_) {
      emit(state.copyWith(
          status: WorkflowDesignerStatus.failure,
          message: 'دریافت طرح فرایند ممکن نشد.'));
    }
  }

  Future<void> addStage(WorkflowStageType type) async {
    final design = state.design;
    if (design == null || state.status == WorkflowDesignerStatus.saving) return;
    final last =
        design.stages.reduce((a, b) => a.sequence > b.sequence ? a : b);
    emit(state.copyWith(
        status: WorkflowDesignerStatus.saving, clearMessage: true));
    try {
      final updated = await repository.addStage(
        definition: definition,
        afterStage: last.id,
        type: type,
      );
      emit(state.copyWith(
          status: WorkflowDesignerStatus.ready, design: updated));
    } catch (_) {
      emit(state.copyWith(
          status: WorkflowDesignerStatus.failure,
          message: 'افزودن مرحله ممکن نشد.'));
    }
  }

  Future<void> saveStart({
    required String triggerType,
    required List<String> initiatorRoles,
    required String subjectSource,
    required String passMode,
  }) async {
    final design = state.design;
    if (design == null) return;
    emit(state.copyWith(
        status: WorkflowDesignerStatus.saving, clearMessage: true));
    try {
      final updated = await repository.saveStartSettings(
        definition: definition,
        triggerType: triggerType,
        initiatorRoles: initiatorRoles,
        subjectSource: subjectSource,
        passMode: passMode,
      );
      final stages = design.stages
          .map((stage) =>
              stage.type == WorkflowStageType.start ? updated : stage)
          .toList();
      emit(state.copyWith(
        status: WorkflowDesignerStatus.ready,
        design: WorkflowDesign(
            workflow: design.workflow,
            stages: stages,
            transitions: design.transitions),
        message: 'تنظیمات شروع ذخیره شد.',
      ));
    } catch (_) {
      emit(state.copyWith(
          status: WorkflowDesignerStatus.failure,
          message: 'ذخیره تنظیمات شروع ممکن نشد.'));
    }
  }

  Future<List<WorkflowFieldOption>> conditionFields() =>
      repository.getConditionFields(definition);

  Future<bool> saveStage(
      WorkflowStage stage, Map<String, dynamic> config) async {
    emit(state.copyWith(
        status: WorkflowDesignerStatus.saving, clearMessage: true));
    try {
      final updated = await repository.saveStageSettings(
        definition: definition,
        stage: stage.id,
        config: config,
      );
      emit(state.copyWith(
        status: WorkflowDesignerStatus.ready,
        design: updated,
        message: 'تنظیمات مرحله ذخیره شد.',
      ));
      return true;
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowDesignerStatus.failure,
        message: 'ذخیره تنظیمات مرحله ممکن نشد.',
      ));
      return false;
    }
  }
}
