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
  });

  final String id, code, title, targetDoctype;
  final WorkflowDefinitionStatus status;
  final bool isLocked;
  final int version, stepsCount;
  final DateTime? modified;
  final String? company, description, moduleKey, creationMode;
  final String? frappeWorkflow, pendingReason, iconKey, colorHex;
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
  });
  final String id, key, title;
  final WorkflowStageType type;
  final int sequence;
  final bool configurationComplete;
  final String? subtype;
  final Map<String, dynamic> config;

  @override
  List<Object?> get props =>
      [id, key, type, title, sequence, configurationComplete, subtype, config];
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
      );

  final String key, label, type;
  final bool required;
  final List<String> options;

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
      };

  WorkflowFormFieldDefinition copyWith({
    String? key,
    String? label,
    String? type,
    bool? required,
    List<String>? options,
  }) =>
      WorkflowFormFieldDefinition(
        key: key ?? this.key,
        label: label ?? this.label,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
      );

  @override
  List<Object> get props => [key, label, type, required, options];
}
