part of 'request_type_builder_cubit.dart';

/// Steps: 0 general info, 1 request form, 2 workflow, 3 access.
class RequestTypeBuilderState extends Equatable {
  const RequestTypeBuilderState({
    this.step = 0,
    this.info = const RequestTypeInfo(title: ''),
    this.active = true,
    this.fields = const [],
    this.definition,
    this.design,
    this.roles = const [],
    this.initiatorRoles = const [],
    this.loading = false,
    this.saving = false,
    this.completed = false,
    this.message,
  });

  final int step;
  final RequestTypeInfo info;
  final bool active;
  final List<WorkflowFormFieldDefinition> fields;
  final WorkflowDefinition? definition;
  final WorkflowDesign? design;
  final List<String> roles, initiatorRoles;
  final bool loading, saving, completed;
  final String? message;

  bool get isEditing => definition != null;

  RequestTypeBuilderState copyWith({
    int? step,
    RequestTypeInfo? info,
    bool? active,
    List<WorkflowFormFieldDefinition>? fields,
    WorkflowDefinition? definition,
    WorkflowDesign? design,
    List<String>? roles,
    List<String>? initiatorRoles,
    bool? loading,
    bool? saving,
    bool? completed,
    String? message,
    bool clearMessage = false,
  }) =>
      RequestTypeBuilderState(
        step: step ?? this.step,
        info: info ?? this.info,
        active: active ?? this.active,
        fields: fields ?? this.fields,
        definition: definition ?? this.definition,
        design: design ?? this.design,
        roles: roles ?? this.roles,
        initiatorRoles: initiatorRoles ?? this.initiatorRoles,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        completed: completed ?? this.completed,
        message: clearMessage ? null : message ?? this.message,
      );

  @override
  List<Object?> get props => [
        step,
        info,
        active,
        fields,
        definition,
        design,
        roles,
        initiatorRoles,
        loading,
        saving,
        completed,
        message,
      ];
}
