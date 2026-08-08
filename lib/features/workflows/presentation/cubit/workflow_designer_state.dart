part of 'workflow_designer_cubit.dart';

enum WorkflowDesignerStatus { initial, loading, ready, saving, failure }

class WorkflowDesignerState extends Equatable {
  const WorkflowDesignerState(
      {this.status = WorkflowDesignerStatus.initial,
      this.design,
      this.options,
      this.message,
      this.offlinePreview = false});
  final WorkflowDesignerStatus status;
  final WorkflowDesign? design;
  final WorkflowFormOptions? options;
  final String? message;
  final bool offlinePreview;

  WorkflowDesignerState copyWith({
    WorkflowDesignerStatus? status,
    WorkflowDesign? design,
    WorkflowFormOptions? options,
    String? message,
    bool clearMessage = false,
    bool? offlinePreview,
  }) =>
      WorkflowDesignerState(
        status: status ?? this.status,
        design: design ?? this.design,
        options: options ?? this.options,
        message: clearMessage ? null : message ?? this.message,
        offlinePreview: offlinePreview ?? this.offlinePreview,
      );

  @override
  List<Object?> get props => [status, design, options, message, offlinePreview];
}
