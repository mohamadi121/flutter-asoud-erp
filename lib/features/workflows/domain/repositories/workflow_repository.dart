import '../entities/workflow_definition.dart';

abstract interface class OfflinePreviewAware {
  bool get isOfflinePreview;
}

abstract interface class WorkflowRepository {
  Future<WorkflowFormOptions> getFormOptions();

  Future<WorkflowDefinition> createDraft({
    required String title,
    required String moduleKey,
    required String targetDoctype,
    required String creationMode,
    String? description,
    String? company,
    String? iconKey,
    String? colorHex,
  });

  Future<WorkflowDesign> getDesign(String definition);

  Future<WorkflowDesign> addStage({
    required String definition,
    required String afterStage,
    required WorkflowStageType type,
  });

  Future<WorkflowDesign> insertStage({
    required String definition,
    required String transition,
    required WorkflowStageType type,
  });

  Future<WorkflowDesign> connectStages({
    required String definition,
    required String fromStage,
    required String toStage,
    required String action,
    Map<String, dynamic> condition = const {},
  });

  Future<WorkflowDesign> updateStagePositions({
    required String definition,
    required Map<String, ({double x, double y})> positions,
  });

  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  });

  Future<WorkflowStage> saveStartSettings({
    required String definition,
    required String triggerType,
    required List<String> initiatorRoles,
    required String subjectSource,
    required String passMode,
  });

  Future<List<WorkflowFieldOption>> getConditionFields(
    String definition, {
    String? beforeStage,
  });

  Future<WorkflowDesign> saveStageSettings({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
  });

  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  });
}
