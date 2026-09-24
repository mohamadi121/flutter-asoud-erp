import 'package:equatable/equatable.dart';

enum WorkflowDefinitionStatus { active, inactive, archived }

class WorkflowDefinition extends Equatable {
  const WorkflowDefinition({
    required this.id,
    required this.code,
    required this.title,
    required this.targetDoctype,
    required this.status,
    required this.isLocked,
    required this.version,
    required this.stepsCount,
    required this.modified,
    this.company,
    this.description,
    this.moduleKey,
    this.creationMode,
    this.frappeWorkflow,
    this.pendingReason,
    this.missingRequirements = const [],
    this.iconKey,
    this.colorHex,
    this.shortTitle,
    this.category,
    this.showInList = true,
    this.userSubmittable = true,
  });

  final String id, code, title, targetDoctype;
  final WorkflowDefinitionStatus status;
  final bool isLocked;
  final int version, stepsCount;
  final DateTime? modified;
  final String? company, description, moduleKey, creationMode;
  final String? frappeWorkflow, pendingReason, iconKey, colorHex;
  final String? shortTitle, category;
  final bool showInList, userSubmittable;
  final List<String> missingRequirements;

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        targetDoctype,
        status,
        isLocked,
        version,
        stepsCount,
        modified,
        company,
        description,
        moduleKey,
        creationMode,
        frappeWorkflow,
        pendingReason,
        missingRequirements,
        iconKey,
        colorHex,
        shortTitle,
        category,
        showInList,
        userSubmittable,
      ];
}

/// Presentation metadata of a request type (a workflow on
/// `ASOUD Workflow Request`).
class RequestTypeInfo extends Equatable {
  const RequestTypeInfo({
    required this.title,
    this.shortTitle = '',
    this.description = '',
    this.category = 'General',
    this.iconKey = 'purchase',
    this.colorHex = '#1769F6',
    this.showInList = true,
    this.userSubmittable = true,
  });

  final String title, shortTitle, description, category, iconKey, colorHex;
  final bool showInList, userSubmittable;

  @override
  List<Object> get props => [
        title,
        shortTitle,
        description,
        category,
        iconKey,
        colorHex,
        showInList,
        userSubmittable,
      ];
}

class WorkflowFormOptions extends Equatable {
  const WorkflowFormOptions({
    required this.companies,
    required this.modules,
    this.roles = const [],
    this.departments = const [],
    this.employees = const [],
  });
  final List<String> companies;
  final List<WorkflowModuleOption> modules;
  final List<String> roles;
  final List<WorkflowTargetOption> departments;
  final List<WorkflowTargetOption> employees;

  @override
  List<Object> get props => [companies, modules, roles, departments, employees];
}

class WorkflowTargetOption extends Equatable {
  const WorkflowTargetOption({
    required this.id,
    required this.label,
    this.department,
    this.company,
  });

  final String id;
  final String label;
  final String? department;
  final String? company;

  @override
  List<Object?> get props => [id, label, department, company];
}

class WorkflowModuleOption extends Equatable {
  const WorkflowModuleOption({required this.key, required this.doctypes});
  final String key;
  final List<WorkflowDoctypeOption> doctypes;

  @override
  List<Object> get props => [key, doctypes];
}

class WorkflowDoctypeOption extends Equatable {
  const WorkflowDoctypeOption({required this.name, required this.available});
  final String name;
  final bool available;

  @override
  List<Object> get props => [name, available];
}

enum WorkflowStageType {
  start,
  userTask,
  approval,
  condition,
  systemAction,
  wait,
  end
}

class WorkflowStage extends Equatable {
  const WorkflowStage({
    required this.id,
    required this.key,
    required this.type,
    required this.title,
    required this.sequence,
    required this.configurationComplete,
    this.subtype,
    this.config = const {},
    this.positionX = 0,
    this.positionY = 0,
  });
  final String id, key, title;
  final WorkflowStageType type;
  final int sequence;
  final bool configurationComplete;
  final String? subtype;
  final Map<String, dynamic> config;
  final double positionX, positionY;

  WorkflowStage copyWith({
    String? title,
    bool? configurationComplete,
    Map<String, dynamic>? config,
    double? positionX,
    double? positionY,
  }) =>
      WorkflowStage(
        id: id,
        key: key,
        type: type,
        title: title ?? this.title,
        sequence: sequence,
        configurationComplete:
            configurationComplete ?? this.configurationComplete,
        subtype: subtype,
        config: config ?? this.config,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
      );

  @override
  List<Object?> get props => [
        id,
        key,
        type,
        title,
        sequence,
        configurationComplete,
        subtype,
        config,
        positionX,
        positionY
      ];
}

class WorkflowTransition extends Equatable {
  const WorkflowTransition({
    required this.id,
    required this.fromStage,
    required this.toStage,
    this.label,
    this.condition = const {},
  });
  final String id, fromStage, toStage;
  final String? label;
  final Map<String, dynamic> condition;
  @override
  List<Object?> get props => [id, fromStage, toStage, label, condition];
}

class WorkflowDesign extends Equatable {
  const WorkflowDesign(
      {required this.workflow,
      required this.stages,
      required this.transitions});
  final WorkflowDefinition workflow;
  final List<WorkflowStage> stages;
  final List<WorkflowTransition> transitions;

  @override
  List<Object> get props => [workflow, stages, transitions];
}

class WorkflowFieldOption extends Equatable {
  const WorkflowFieldOption(
      {required this.name,
      required this.label,
      required this.type,
      this.source = 'Document'});
  final String name, label, type;
  final String source;
  @override
  List<Object> get props => [name, label, type, source];
}

class WorkflowFormFieldDefinition extends Equatable {
  const WorkflowFormFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.defaultValue = '',
    this.helpText = '',
    this.showInList = false,
  });

  factory WorkflowFormFieldDefinition.fromMap(Map<dynamic, dynamic> map) =>
      WorkflowFormFieldDefinition(
        key: map['key']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
        type: map['type']?.toString() ?? 'Short Text',
        required: map['required'] == true || map['required'] == 1,
        options: map['options'] is List
            ? (map['options'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
            : const [],
        defaultValue: map['default_value']?.toString() ?? '',
        helpText: map['help_text']?.toString() ?? '',
        showInList: map['show_in_list'] == true || map['show_in_list'] == 1,
      );

  final String key, label, type;
  final bool required;
  final List<String> options;
  final String defaultValue, helpText;
  final bool showInList;

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
        if (defaultValue.isNotEmpty) 'default_value': defaultValue,
        if (helpText.isNotEmpty) 'help_text': helpText,
        if (showInList) 'show_in_list': true,
      };

  WorkflowFormFieldDefinition copyWith({
    String? key,
    String? label,
    String? type,
    bool? required,
    List<String>? options,
    String? defaultValue,
    String? helpText,
    bool? showInList,
  }) =>
      WorkflowFormFieldDefinition(
        key: key ?? this.key,
        label: label ?? this.label,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
        defaultValue: defaultValue ?? this.defaultValue,
        helpText: helpText ?? this.helpText,
        showInList: showInList ?? this.showInList,
      );

  @override
  List<Object> get props => [
        key,
        label,
        type,
        required,
        options,
        defaultValue,
        helpText,
        showInList,
      ];
}
