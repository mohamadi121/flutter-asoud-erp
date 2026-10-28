import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/utils/failure_message.dart';

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

  Future<WorkflowStage?> addStage(WorkflowStageType type) async {
    final design = state.design;
    if (design == null || design.stages.isEmpty || state.status == WorkflowDesignerStatus.saving) return null;
    final last =
        design.stages.reduce((a, b) => a.sequence > b.sequence ? a : b);
    emit(state.copyWith(
        status: WorkflowDesignerStatus.saving, clearMessage: true));
    try {
      final previousIds = design.stages.map((stage) => stage.id).toSet();
      final incoming = design.transitions.where((edge) => edge.toStage == last.id).toList();
      if (last.type == WorkflowStageType.end && incoming.length != 1) {
        emit(state.copyWith(status: WorkflowDesignerStatus.failure,
            message: 'برای افزودن مرحله، مسیر موردنظر را از روی نمودار انتخاب کنید.'));
        return null;
      }
      var updated = last.type == WorkflowStageType.end
          ? await repository.insertStage(definition: definition,
              transition: incoming.single.id, type: type)
          : await repository.addStage(definition: definition, afterStage: last.id, type: type);
      final created = updated.stages.where((stage) => !previousIds.contains(stage.id) && stage.type == type).firstOrNull;
      if (isClosed) return null;
      if (type == WorkflowStageType.userTask && created != null &&
          !updated.stages.any((stage) => stage.type == WorkflowStageType.end)) {
        // A new custom design starts with only Start. Supply a real End so the
        // user-task form has a valid completion destination from its first open.
        emit(state.copyWith(status: WorkflowDesignerStatus.saving, design: updated));
        updated = await repository.addStage(definition: definition,
            afterStage: created.id, type: WorkflowStageType.end);
      }
      if (isClosed) return null;
      emit(state.copyWith(
          status: WorkflowDesignerStatus.ready, design: updated));
      return created == null ? null : updated.stages.where((stage) => stage.id == created.id).firstOrNull;
    } catch (error) {
      if (isClosed) return null;
      emit(state.copyWith(
          status: WorkflowDesignerStatus.failure,
          message: failureDetail(error)));
      return null;
    }
  }

  Future<void> insertStage(String transition, WorkflowStageType type) async {
    if (state.design == null) return;
    emit(state.copyWith(status: WorkflowDesignerStatus.saving));
    try {
      final design = await repository.insertStage(
        definition: definition,
        transition: transition,
        type: type,
      );
      emit(
          state.copyWith(status: WorkflowDesignerStatus.ready, design: design));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowDesignerStatus.failure,
        message: 'افزودن مرحله بین مسیرها ممکن نشد.',
      ));
    }
  }

  Future<void> connectStages({
    required String fromStage,
    required String toStage,
    required String action,
  }) async {
    if (state.design == null) return;
    emit(state.copyWith(status: WorkflowDesignerStatus.saving));
    try {
      final design = await repository.connectStages(
        definition: definition,
        fromStage: fromStage,
        toStage: toStage,
        action: action,
      );
      emit(
          state.copyWith(status: WorkflowDesignerStatus.ready, design: design));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowDesignerStatus.failure,
        message: 'ایجاد مسیر ممکن نشد.',
      ));
    }
  }

  void moveStage(String id, double x, double y) {
    final design = state.design;
    if (design == null) return;
    emit(state.copyWith(
      design: WorkflowDesign(
        workflow: design.workflow,
        stages: design.stages
            .map((item) => item.id == id
                ? item.copyWith(positionX: x, positionY: y)
                : item)
            .toList(growable: false),
        transitions: design.transitions,
      ),
    ));
  }

  Future<void> savePositions() async {
    final design = state.design;
    if (design == null) return;
    try {
      final updated = await repository.updateStagePositions(
        definition: definition,
        positions: {
          for (final stage in design.stages)
            stage.id: (x: stage.positionX, y: stage.positionY),
        },
      );
      emit(state.copyWith(
        status: WorkflowDesignerStatus.ready,
        design: updated,
        message: 'چیدمان مراحل ذخیره شد.',
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowDesignerStatus.failure,
        message: 'ذخیره چیدمان ممکن نشد.',
      ));
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
    } catch (error) {
      emit(state.copyWith(
        status: WorkflowDesignerStatus.failure,
        message: failureDetail(error),
      ));
      return false;
    }
  }
}
