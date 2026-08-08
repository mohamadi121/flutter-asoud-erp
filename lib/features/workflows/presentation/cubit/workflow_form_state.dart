part of 'workflow_form_cubit.dart';

enum WorkflowFormStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure
}

class WorkflowFormState extends Equatable {
  const WorkflowFormState({
    this.status = WorkflowFormStatus.initial,
    this.title = '',
    this.description = '',
    this.company = '',
    this.moduleKey = '',
    this.targetDoctype = '',
    this.creationMode = 'Custom',
    this.iconKey = 'hub',
    this.colorHex = '#315CF5',
    this.options,
    this.titleError,
    this.message,
    this.createdDraft,
    this.offlinePreview = false,
  });

  final WorkflowFormStatus status;
  final String title, description, company, moduleKey, targetDoctype;
  final String creationMode, iconKey, colorHex;
  final WorkflowFormOptions? options;
  final String? titleError, message;
  final WorkflowDefinition? createdDraft;
  final bool offlinePreview;

  WorkflowFormState copyWith({
    WorkflowFormStatus? status,
    String? title,
    String? description,
    String? company,
    String? moduleKey,
    String? targetDoctype,
    String? creationMode,
    String? iconKey,
    String? colorHex,
    WorkflowFormOptions? options,
    String? titleError,
    bool clearTitleError = false,
    String? message,
    bool clearMessage = false,
    WorkflowDefinition? createdDraft,
    bool? offlinePreview,
  }) =>
      WorkflowFormState(
        status: status ?? this.status,
        title: title ?? this.title,
        description: description ?? this.description,
        company: company ?? this.company,
        moduleKey: moduleKey ?? this.moduleKey,
        targetDoctype: targetDoctype ?? this.targetDoctype,
        creationMode: creationMode ?? this.creationMode,
        iconKey: iconKey ?? this.iconKey,
        colorHex: colorHex ?? this.colorHex,
        options: options ?? this.options,
        titleError: clearTitleError ? null : titleError ?? this.titleError,
        message: clearMessage ? null : message ?? this.message,
        createdDraft: createdDraft ?? this.createdDraft,
        offlinePreview: offlinePreview ?? this.offlinePreview,
      );

  @override
  List<Object?> get props => [
        status,
        title,
        description,
        company,
        moduleKey,
        targetDoctype,
        creationMode,
        iconKey,
        colorHex,
        options,
        titleError,
        message,
        createdDraft,
        offlinePreview,
      ];
}
