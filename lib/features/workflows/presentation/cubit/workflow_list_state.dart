part of 'workflow_list_cubit.dart';

enum WorkflowListLoadStatus { initial, loading, success, failure }

class WorkflowListState extends Equatable {
  const WorkflowListState({
    this.status = WorkflowListLoadStatus.initial,
    this.items = const [],
    this.search = '',
    this.filter,
    this.orderBy = 'modified desc',
    this.message,
    this.offlinePreview = false,
  });

  final WorkflowListLoadStatus status;
  final List<WorkflowDefinition> items;
  final String search, orderBy;
  final WorkflowDefinitionStatus? filter;
  final String? message;
  final bool offlinePreview;

  WorkflowListState copyWith({
    WorkflowListLoadStatus? status,
    List<WorkflowDefinition>? items,
    String? search,
    WorkflowDefinitionStatus? filter,
    bool clearFilter = false,
    String? orderBy,
    String? message,
    bool clearMessage = false,
    bool? offlinePreview,
  }) =>
      WorkflowListState(
        status: status ?? this.status,
        items: items ?? this.items,
        search: search ?? this.search,
        filter: clearFilter ? null : filter ?? this.filter,
        orderBy: orderBy ?? this.orderBy,
        message: clearMessage ? null : message ?? this.message,
        offlinePreview: offlinePreview ?? this.offlinePreview,
      );

  @override
  List<Object?> get props =>
      [status, items, search, filter, orderBy, message, offlinePreview];
}
