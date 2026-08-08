import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

class FrappeWorkflowRepository implements WorkflowRepository {
  const FrappeWorkflowRepository(this._client);
  final FrappeApiClient _client;

  @override
  Future<WorkflowDesign> getDesign(String definition) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.get_workflow_design',
      data: {'definition': definition},
    );
    return _parseDesign(data);
  }

  @override
  Future<WorkflowDesign> addStage({
    required String definition,
    required String afterStage,
    required WorkflowStageType type,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.add_workflow_stage',
      data: {
        'definition': definition,
        'after_stage': afterStage,
        'stage_type': _stageTypeValue(type),
      },
    );
    return _parseDesign(data);
  }

  @override
  Future<WorkflowStage> saveStartSettings({
    required String definition,
    required String triggerType,
    required List<String> initiatorRoles,
    required String subjectSource,
    required String passMode,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.save_start_settings',
      data: {
        'definition': definition,
        'trigger_type': triggerType,
        'initiator_roles': initiatorRoles,
        'subject_source': subjectSource,
        'pass_mode': passMode,
      },
    );
    if (data is! Map) throw StateError('Invalid start stage response');
    return _parseStage(data);
  }

  @override
  Future<List<WorkflowFieldOption>> getConditionFields(
      String definition) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.workflow_condition_fields',
      data: {'definition': definition},
    );
    if (data is! Map || data['fields'] is! List) {
      throw StateError('Invalid workflow fields response');
    }
    return (data['fields'] as List).whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WorkflowFieldOption(
        name: item['fieldname']?.toString() ?? '',
        label: item['label']?.toString() ?? '',
        type: item['fieldtype']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  @override
  Future<WorkflowDesign> saveStageSettings({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.save_stage_settings',
      data: {'definition': definition, 'stage': stage, 'config': config},
    );
    return _parseDesign(data);
  }

  @override
  Future<WorkflowFormOptions> getFormOptions() async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.workflow_form_options',
    );
    if (data is! Map) throw StateError('Invalid workflow options response');
    final item = Map<String, dynamic>.from(data);
    final companies = item['companies'];
    final modules = item['modules'];
    final roles = item['roles'];
    return WorkflowFormOptions(
      companies: companies is List
          ? companies.map((value) => value.toString()).toList(growable: false)
          : const [],
      modules: modules is List
          ? modules.whereType<Map>().map((raw) {
              final module = Map<String, dynamic>.from(raw);
              final doctypes = module['doctypes'];
              return WorkflowModuleOption(
                key: module['key']?.toString() ?? '',
                doctypes: doctypes is List
                    ? doctypes.whereType<Map>().map((rawDoctype) {
                        final doctype = Map<String, dynamic>.from(rawDoctype);
                        return WorkflowDoctypeOption(
                          name: doctype['name']?.toString() ?? '',
                          available: doctype['available'] == true ||
                              doctype['available'] == 1,
                        );
                      }).toList(growable: false)
                    : const [],
              );
            }).toList(growable: false)
          : const [],
      roles: roles is List
          ? roles.map((value) => value.toString()).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<WorkflowDefinition> createDraft({
    required String title,
    required String moduleKey,
    required String targetDoctype,
    required String creationMode,
    String? description,
    String? company,
    String? iconKey,
    String? colorHex,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.create_workflow_draft',
      data: {
        'workflow_title': title,
        'module_key': moduleKey,
        'target_doctype': targetDoctype,
        'creation_mode': creationMode,
        if (description?.trim().isNotEmpty == true)
          'process_description': description!.trim(),
        if (company?.trim().isNotEmpty == true) 'company': company!.trim(),
        if (iconKey != null) 'icon_key': iconKey,
        if (colorHex != null) 'color_hex': colorHex,
      },
    );
    if (data is! Map) throw StateError('Invalid workflow draft response');
    return _parse(data);
  }

  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow.list_workflows',
      data: {
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (status != null) 'status': _statusValue(status),
        if (company?.trim().isNotEmpty == true) 'company': company!.trim(),
        'order_by': orderBy,
      },
    );
    if (data is! List) throw StateError('Invalid workflow response');
    return data.whereType<Map>().map(_parse).toList(growable: false);
  }

  WorkflowDefinition _parse(Map raw) {
    final item = Map<String, dynamic>.from(raw);
    final missing = item['missing_requirements'];
    return WorkflowDefinition(
      id: item['name']?.toString() ?? '',
      code: item['workflow_code']?.toString() ?? '',
      title: item['workflow_title']?.toString() ?? '',
      targetDoctype: item['target_doctype']?.toString() ?? '',
      status: _parseStatus(item['status']?.toString()),
      isLocked: item['is_locked'] == true || item['is_locked'] == 1,
      version: int.tryParse(item['version_no']?.toString() ?? '') ?? 1,
      stepsCount: int.tryParse(item['steps_count']?.toString() ?? '') ?? 0,
      modified: DateTime.tryParse(item['modified']?.toString() ?? ''),
      company: item['company']?.toString(),
      description: item['process_description']?.toString(),
      moduleKey: item['module_key']?.toString(),
      creationMode: item['creation_mode']?.toString(),
      frappeWorkflow: item['frappe_workflow']?.toString(),
      pendingReason: item['pending_reason']?.toString(),
      missingRequirements: missing is List
          ? missing.map((value) => value.toString()).toList(growable: false)
          : const [],
      iconKey: item['icon_key']?.toString(),
      colorHex: item['color_hex']?.toString(),
    );
  }

  WorkflowDesign _parseDesign(dynamic data) {
    if (data is! Map) throw StateError('Invalid workflow design response');
    final raw = Map<String, dynamic>.from(data);
    final workflow = raw['workflow'];
    final stages = raw['stages'];
    final transitions = raw['transitions'];
    if (workflow is! Map || stages is! List || transitions is! List) {
      throw StateError('Incomplete workflow design response');
    }
    return WorkflowDesign(
      workflow: _parse(workflow),
      stages: stages.whereType<Map>().map(_parseStage).toList(growable: false),
      transitions: transitions.whereType<Map>().map((item) {
        final value = Map<String, dynamic>.from(item);
        return WorkflowTransition(
          id: value['name']?.toString() ?? '',
          fromStage: value['from_stage']?.toString() ?? '',
          toStage: value['to_stage']?.toString() ?? '',
        );
      }).toList(growable: false),
    );
  }

  WorkflowStage _parseStage(Map raw) {
    final item = Map<String, dynamic>.from(raw);
    final config = item['config'];
    return WorkflowStage(
      id: item['name']?.toString() ?? '',
      key: item['stage_key']?.toString() ?? '',
      type: _parseStageType(item['stage_type']?.toString()),
      subtype: item['stage_subtype']?.toString(),
      title: item['stage_title']?.toString() ?? '',
      sequence: int.tryParse(item['sequence_no']?.toString() ?? '') ?? 0,
      configurationComplete: item['configuration_status'] == 'Complete',
      config: config is Map ? Map<String, dynamic>.from(config) : const {},
    );
  }

  String _stageTypeValue(WorkflowStageType type) => switch (type) {
        WorkflowStageType.start => 'Start',
        WorkflowStageType.userTask => 'User Task',
        WorkflowStageType.approval => 'Approval',
        WorkflowStageType.condition => 'Condition',
        WorkflowStageType.systemAction => 'System Action',
        WorkflowStageType.wait => 'Wait',
        WorkflowStageType.end => 'End',
      };

  WorkflowStageType _parseStageType(String? value) => switch (value) {
        'User Task' => WorkflowStageType.userTask,
        'Approval' => WorkflowStageType.approval,
        'Condition' => WorkflowStageType.condition,
        'System Action' => WorkflowStageType.systemAction,
        'Wait' => WorkflowStageType.wait,
        'End' => WorkflowStageType.end,
        _ => WorkflowStageType.start,
      };

  String _statusValue(WorkflowDefinitionStatus status) => switch (status) {
        WorkflowDefinitionStatus.active => 'Active',
        WorkflowDefinitionStatus.inactive => 'Inactive',
        WorkflowDefinitionStatus.archived => 'Archived',
      };

  WorkflowDefinitionStatus _parseStatus(String? status) => switch (status) {
        'Active' => WorkflowDefinitionStatus.active,
        'Archived' => WorkflowDefinitionStatus.archived,
        _ => WorkflowDefinitionStatus.inactive,
      };
}
