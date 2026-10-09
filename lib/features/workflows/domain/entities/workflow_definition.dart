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

/// Workflow presentation metadata. Request-only flags are ignored by the server
/// for workflows referencing native business documents.
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
    this.moduleKey,
  });

  final String title, shortTitle, description, category, iconKey, colorHex;
  final String? moduleKey;
  final bool showInList, userSubmittable;

  @override
  List<Object?> get props => [
        title,
        shortTitle,
        description,
        category,
        iconKey,
        colorHex,
        showInList,
        userSubmittable,
        moduleKey,
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
    this.parent,
    this.isGroup = false,
    this.designation,
  });

  final String id;
  final String label;
  final String? department;
  final String? company;

  /// Departments: the parent department and whether it groups others.
  final String? parent;
  final bool isGroup;

  /// Employees: their designation, shown under the name.
  final String? designation;

  @override
  List<Object?> get props =>
      [id, label, department, company, parent, isGroup, designation];
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

/// `visible_when` of a form field: shown only while the controlling field's
/// value equals [equals] or is one of [inList].
class VisibleWhen extends Equatable {
  const VisibleWhen({required this.field, this.equals, this.inList = const []});

  factory VisibleWhen.fromMap(Map<dynamic, dynamic> map) => VisibleWhen(
        field: map['field']?.toString() ?? '',
        equals: map['equals'],
        inList: map['in'] is List
            ? List<Object?>.unmodifiable(map['in'] as List)
            : const [],
      );

  final String field;
  final Object? equals;
  final List<Object?> inList;

  bool get usesList => inList.isNotEmpty;

  /// Whether [value] (the controlling field's current value) shows the field.
  bool matches(Object? value) =>
      usesList ? inList.any((item) => item == value) : equals == value;

  Map<String, dynamic> toMap() => {
        'field': field,
        if (usesList) 'in': inList else 'equals': equals,
      };

  @override
  List<Object?> get props => [field, equals, inList];
}

/// `row_options` of an «Item Table» field.
class RowOptions extends Equatable {
  const RowOptions({
    this.itemScope = 'all',
    this.note = false,
    this.attachment = false,
    this.minRows,
    this.maxRows,
  });

  factory RowOptions.fromMap(Map<dynamic, dynamic> map) => RowOptions(
        itemScope: map['item_scope']?.toString() ?? 'all',
        note: map['note'] == true || map['note'] == 1,
        attachment: map['attachment'] == true || map['attachment'] == 1,
        minRows: (map['min_rows'] as num?)?.toInt(),
        maxRows: (map['max_rows'] as num?)?.toInt(),
      );

  /// `purchase` limits the picker to purchase items; `all` allows any item.
  final String itemScope;
  final bool note, attachment;
  final int? minRows, maxRows;

  Map<String, dynamic> toMap() => {
        'item_scope': itemScope,
        'note': note,
        'attachment': attachment,
        if (minRows != null) 'min_rows': minRows,
        if (maxRows != null) 'max_rows': maxRows,
      };

  @override
  List<Object?> get props => [itemScope, note, attachment, minRows, maxRows];
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
    this.columns = const [],
    this.source,
    this.auto,
    this.visibleWhen,
    this.optionLabels = const {},
    this.widget,
    this.defaultLabel,
    this.editable = true,
    this.minDate,
    this.maxLength,
    this.rowOptions,
    this.defaultSource,
    this.requiredBySetting,
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
        columns: map['columns'] is List
            ? (map['columns'] as List)
                .whereType<Map>()
                .map(WorkflowFormFieldDefinition.fromMap)
                .toList(growable: false)
            : const [],
        source: _text(map['source']),
        auto: _text(map['auto']),
        visibleWhen: map['visible_when'] is Map
            ? VisibleWhen.fromMap(map['visible_when'] as Map)
            : null,
        optionLabels: map['option_labels'] is Map
            ? Map<String, String>.unmodifiable({
                for (final entry in (map['option_labels'] as Map).entries)
                  entry.key.toString(): entry.value.toString()
              })
            : const {},
        widget: _text(map['widget']),
        defaultLabel: _text(map['default_label']),
        editable: !(map['editable'] == false || map['editable'] == 0),
        minDate: _text(map['min_date']),
        maxLength: (map['max_length'] as num?)?.toInt(),
        rowOptions: map['row_options'] is Map
            ? RowOptions.fromMap(map['row_options'] as Map)
            : null,
        defaultSource: _text(map['default_source']),
        requiredBySetting: _text(map['required_by_setting']),
      );

  static String? _text(Object? value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  final String key, label, type;
  final bool required;
  final List<String> options;
  final String defaultValue, helpText;
  final bool showInList;
  final List<WorkflowFormFieldDefinition> columns;

  /// `System Select` source (`cost_center`, `project`, `leave_type`, ...).
  final String? source;

  /// `Auto` kind (`request_number`, `request_date`, `leave_duration`).
  final String? auto;
  final VisibleWhen? visibleWhen;

  /// `Choice`: stored value to Persian label.
  final Map<String, String> optionLabels;

  /// `segmented`, `chips`, `dropdown` or `textarea`.
  final String? widget;

  /// Label of [defaultValue], resolved by the server (`default_label`).
  final String? defaultLabel;
  final bool editable;

  /// Only `today`: the date may not be earlier.
  final String? minDate;
  final int? maxLength;
  final RowOptions? rowOptions;

  /// Server-side `default_source`; replaced by [defaultValue] in
  /// `request_options` responses, kept so definitions round-trip.
  final String? defaultSource;
  final String? requiredBySetting;

  /// Persian label of a `Choice` value, falling back to the value itself.
  String optionLabel(String value) => optionLabels[value] ?? value;

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
        if (defaultValue.isNotEmpty) 'default_value': defaultValue,
        if (helpText.isNotEmpty) 'help_text': helpText,
        if (showInList) 'show_in_list': true,
        if (type == 'Table')
          'columns': columns.map((column) => column.toMap()).toList(),
        if (source != null) 'source': source,
        if (auto != null) 'auto': auto,
        if (visibleWhen != null) 'visible_when': visibleWhen!.toMap(),
        if (optionLabels.isNotEmpty) 'option_labels': optionLabels,
        if (widget != null) 'widget': widget,
        if (defaultLabel != null) 'default_label': defaultLabel,
        if (!editable) 'editable': false,
        if (minDate != null) 'min_date': minDate,
        if (maxLength != null) 'max_length': maxLength,
        if (rowOptions != null) 'row_options': rowOptions!.toMap(),
        if (defaultSource != null) 'default_source': defaultSource,
        if (requiredBySetting != null) 'required_by_setting': requiredBySetting,
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
    List<WorkflowFormFieldDefinition>? columns,
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
        columns: columns ?? this.columns,
        source: source,
        auto: auto,
        visibleWhen: visibleWhen,
        optionLabels: optionLabels,
        widget: widget,
        defaultLabel: defaultLabel,
        editable: editable,
        minDate: minDate,
        maxLength: maxLength,
        rowOptions: rowOptions,
        defaultSource: defaultSource,
        requiredBySetting: requiredBySetting,
      );

  @override
  List<Object?> get props => [
        key,
        label,
        type,
        required,
        options,
        defaultValue,
        helpText,
        showInList,
        columns,
        source,
        auto,
        visibleWhen,
        optionLabels,
        widget,
        defaultLabel,
        editable,
        minDate,
        maxLength,
        rowOptions,
        defaultSource,
        requiredBySetting,
      ];
}
