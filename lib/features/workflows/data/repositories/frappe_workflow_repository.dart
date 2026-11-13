import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_start_settings.dart';
import '../../domain/repositories/workflow_repository.dart';

class FrappeWorkflowRepository implements WorkflowRepository, WorkflowStartSettingsRepository, WorkflowDraftStartRepository {
  const FrappeWorkflowRepository(this._client);
  final FrappeApiClient _client;
  @override
  Future<void> validateStartSelection(String company, WorkflowStartSettings settings, {String? definition}) async {
    final response = await _client.callMethod('asoud_erp.api.v1.workflow.save_start_settings', data: {
      'definition': definition ?? '', 'company': company, 'validate_only': 1, 'settings': settings.toMap(),
      'trigger_type': settings.manual ? 'Manual' : 'Document Event', 'initiator_roles': settings.roles,
      'subject_source': 'Referenced Document'});
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || (envelope['data'] as Map?)?['valid'] != true) {
      throw const ApiException.protocol();
    }
  }
  @override
  Future<WorkflowDefinition> createInitializedDraft(Map<String, dynamic> info, WorkflowStartSettings settings) async {
    final response = await _client.callMethod('asoud_erp.api.v1.workflow.create_workflow_draft',
      data: {...info, 'start_settings': settings.toMap()});
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || envelope['data'] is! Map) throw const ApiException.protocol();
    final draft = _parse(envelope['data'] as Map);
    // Confirm from the same transaction response; a second failing HTTP read
    // must not leave a committed draft looking like a failed creation.
    final config = (envelope['data'] as Map)['start_settings'];
    final source = config is Map ? config['submission_source'] : null;
    if (config is! Map || config['start_settings_version'] != 1 || config['trigger_type'] !=
        (settings.manual ? 'Manual' : 'Document Event') || (!settings.manual &&
          (source is! Map || source['form'] != settings.source?['form'] || source['revision'] != settings.source?['revision']))) {
      throw const ApiException(kind: ApiFailureKind.validation,
        message: 'تنظیمات شروع ثبت نشد؛ سرور باید به نسخهٔ هماهنگ به‌روزرسانی شود.');
    }
    return draft;
  }
  @override
  bool get localStartSettings => !_client.isAuthenticated;
  @override
  Future<WorkflowStage> configureStart(String definition, WorkflowStartSettings settings) async {
    final response = await _client.callMethod('asoud_erp.api.v1.workflow.save_start_settings', data: {
      'definition': definition, 'trigger_type': settings.manual ? 'Manual' : 'Document Event',
      'initiator_roles': settings.roles, 'subject_source': settings.manual ? 'General Subject' : 'Referenced Document',
      'settings': settings.toMap(),
    });
    final envelope = response['message'];
    final value = envelope is Map && envelope['ok'] == true ? envelope['data'] : null;
    if (value is! Map) throw const ApiException.protocol();
    final stage = _parseStage(value);
    if (stage.config['start_settings_version'] != 1 ||
        stage.config['trigger_type'] != (settings.manual ? 'Manual' : 'Document Event')) {
      throw const ApiException(kind: ApiFailureKind.validation,
        message: 'سرور هنوز از تنظیمات جدید شروع پشتیبانی نمی‌کند؛ ابتدا سرور را به‌روزرسانی کنید.');
    }
    return stage;
  }

  Future<dynamic> _call(String method, {Map<String, dynamic>? data}) async {
    return _client.callAsoudMethod(method, data: data);
  }

  @override
  Future<WorkflowDesign> getDesign(String definition) async {
    final data = await _call(
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
    final data = await _call(
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
  Future<WorkflowDesign> insertStage({
    required String definition,
    required String transition,
    required WorkflowStageType type,
  }) async =>
      _parseDesign(await _call(
        'asoud_erp.api.v1.workflow.insert_workflow_stage',
        data: {
          'definition': definition,
          'transition': transition,
          'stage_type': _stageTypeValue(type),
        },
      ));

  @override
  Future<WorkflowDesign> connectStages({
    required String definition,
    required String fromStage,
    required String toStage,
    required String action,
    Map<String, dynamic> condition = const {},
  }) async =>
      _parseDesign(await _call(
        'asoud_erp.api.v1.workflow.connect_workflow_stages',
        data: {
          'definition': definition,
          'from_stage': fromStage,
          'to_stage': toStage,
          'action': action,
          'condition': condition,
        },
      ));

  @override
  Future<WorkflowDesign> updateStagePositions({
    required String definition,
    required Map<String, ({double x, double y})> positions,
  }) async =>
      _parseDesign(await _call(
        'asoud_erp.api.v1.workflow.update_stage_positions',
        data: {
          'definition': definition,
          'positions': positions.map((key, value) => MapEntry(
                key,
                {'x': value.x, 'y': value.y},
              )),
        },
      ));

  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.add_condition_branch',
      data: {
        'definition': definition,
        'condition_stage': conditionStage,
        'stage_type': _stageTypeValue(type),
        'result': result,
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
    final data = await _call(
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
    String definition, {
    String? beforeStage,
  }) async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.workflow_condition_fields',
      data: {
        'definition': definition,
        if (beforeStage != null) 'stage': beforeStage,
      },
    );
    if (data is! Map || data['fields'] is! List) {
      throw StateError('Invalid workflow fields response');
    }
    if (beforeStage != null && data['condition_fields_v2'] is List) {
      return (data['condition_fields_v2'] as List).whereType<Map>().map((raw) => WorkflowFieldOption(
        name: '${raw['source_field']}', label: persianDocumentFieldLabel('${raw['label']}'), type: '${raw['field_type']}',
        source: '${raw['source_kind']}', sourceStage: '${raw['source_stage'] ?? ''}',
        stageTitle: '${raw['stage_title'] ?? ''}', conditionVersion: 2,
        linkDoctype: raw['link_doctype'] as String?, currency: raw['currency'] as String?,
        dataType: raw['data_type'] as String?,
        choices: List<String>.from(raw['options'] as List? ?? []),
        choiceLabels: Map<String, String>.from(raw['option_labels'] as Map? ?? {}))).toList();
    }
    return (data['fields'] as List).whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WorkflowFieldOption(
        name: item['fieldname']?.toString() ?? '',
        label: item['label']?.toString() ?? '',
        type: item['fieldtype']?.toString() ?? '',
        source: item['source']?.toString() ?? 'Document',
      );
    }).toList(growable: false);
  }

  @override
  Future<WorkflowDesign> saveStageSettings({
    required String definition,
    required String stage,
    required Map<String, dynamic> config,
  }) async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.save_stage_settings',
      data: {'definition': definition, 'stage': stage, 'config': config},
    );
    return _parseDesign(data);
  }

  @override
  Future<WorkflowFormOptions> getFormOptions() async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.workflow_form_options',
    );
    if (data is! Map) throw StateError('Invalid workflow options response');
    final item = Map<String, dynamic>.from(data);
    final companies = item['companies'];
    final modules = item['modules'];
    final roles = item['roles'];
    final departments = item['departments'];
    final employees = item['employees'];
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
      departments: _parseTargets(departments, labelKey: 'department_name'),
      employees: _parseTargets(employees, labelKey: 'employee_name'),
    );
  }

  String? _optionalText(Object? value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  List<WorkflowTargetOption> _parseTargets(dynamic raw,
      {required String labelKey}) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((value) {
          final item = Map<String, dynamic>.from(value);
          return WorkflowTargetOption(
            id: item['name']?.toString() ?? '',
            label: item[labelKey]?.toString() ?? item['name']?.toString() ?? '',
            department: item['department']?.toString(),
            company: item['company']?.toString(),
            parent: _optionalText(item['parent_department']),
            isGroup: item['is_group'] == 1 || item['is_group'] == true,
            designation: _optionalText(item['designation']),
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
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
    final data = await _call(
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
  Future<WorkflowDefinition> saveRequestTypeInfo({
    required String definition,
    required RequestTypeInfo info,
  }) async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.update_request_type_info',
      data: {
        'name': definition,
        'workflow_title': info.title,
        if (info.moduleKey != null) 'module_key': info.moduleKey,
        'short_title': info.shortTitle,
        'process_description': info.description,
        'request_category': info.category,
        'icon_key': info.iconKey,
        'color_hex': info.colorHex,
        'show_in_request_list': info.showInList ? 1 : 0,
        'allow_user_submission': info.userSubmittable ? 1 : 0,
      },
    );
    if (data is! Map) throw StateError('Invalid request type response');
    return _parse(data);
  }

  @override
  Future<WorkflowDefinition> setWorkflowStatus({
    required String definition,
    required WorkflowDefinitionStatus status,
  }) async {
    final data = await _call(
      'asoud_erp.api.v1.workflow.set_workflow_status',
      data: {'name': definition, 'status': _statusValue(status)},
    );
    if (data is! Map) throw StateError('Invalid workflow status response');
    return _parse(data);
  }

  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async {
    final data = await _call(
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

  /// Shared decoding for additive workflow endpoints with the same contract.
  WorkflowDefinition parseDefinition(Map raw) => _parse(raw);

  WorkflowDefinition _parse(Map raw) {
    final item = Map<String, dynamic>.from(raw);
    final missing = item['missing_requirements'];
    return WorkflowDefinition(
      id: item['name']?.toString() ?? '',
      canStartManual: item['can_start_manual'] == true || item['can_start_manual'] == 1,
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
      pendingReason: item['pending_reason'] == null
          ? null
          : persianServerMessage(item['pending_reason'].toString()),
      missingRequirements: missing is List
          ? missing
              .map((value) => persianServerMessage(value.toString()))
              .toList(growable: false)
          : const [],
      iconKey: item['icon_key']?.toString(),
      colorHex: item['color_hex']?.toString(),
      shortTitle: item['short_title']?.toString(),
      category: item['request_category']?.toString(),
      showInList: item['show_in_request_list'] != 0 &&
          item['show_in_request_list'] != false,
      userSubmittable: item['allow_user_submission'] != 0 &&
          item['allow_user_submission'] != false,
      isSystemTemplate:
          item['is_system_template'] == 1 || item['is_system_template'] == true,
      templateKey: item['template_key']?.toString(),
      canDelete: item['can_delete'] == true || item['can_delete'] == 1,
    );
  }

  WorkflowDesign _parseDesign(dynamic data) {
    if (data is! Map) throw StateError('Invalid workflow design response');
    final raw = Map<String, dynamic>.from(data);
    final workflow = raw['workflow'];
    final stages = raw['stages'];
    final transitions = raw['transitions'];
    final details = raw['details_summary'];
    if (details != null && (details is! Map || details['steps_count'] is! int ||
        details['stages_complete'] is! bool || details['routes_complete'] is! bool ||
        details['requirements'] is! List ||
        (details['requirements'] as List).any((value) => value is! String))) {
      throw const ApiException.protocol();
    }
    if (workflow is! Map || stages is! List || transitions is! List) {
      throw StateError('Incomplete workflow design response');
    }
    return WorkflowDesign(
      workflow: _parse(workflow),
      detailsSummary: details == null ? null : WorkflowDetailsSummary(
        stepsCount: details['steps_count'] as int,
        stagesComplete: details['stages_complete'] as bool,
        routesComplete: details['routes_complete'] as bool,
        requirements: List<String>.from(details['requirements'] as List)),
      stages: stages.whereType<Map>().map(_parseStage).toList(growable: false),
      transitions: transitions.whereType<Map>().map((item) {
        final value = Map<String, dynamic>.from(item);
        return WorkflowTransition(
          id: value['name']?.toString() ?? '',
          fromStage: value['from_stage']?.toString() ?? '',
          toStage: value['to_stage']?.toString() ?? '',
          label: persianTransitionLabel(value['transition_label']?.toString()),
          condition: value['condition'] is Map
              ? Map<String, dynamic>.from(value['condition'] as Map)
              : const {},
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
      title: persianWorkflowStageTitle(item['stage_title']?.toString() ?? ''),
      sequence: int.tryParse(item['sequence_no']?.toString() ?? '') ?? 0,
      configurationComplete: item['configuration_status'] == 'Complete',
      config: config is Map ? Map<String, dynamic>.from(config) : const {},
      positionX: double.tryParse(item['position_x']?.toString() ?? '') ?? 0,
      positionY: double.tryParse(item['position_y']?.toString() ?? '') ?? 0,
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
