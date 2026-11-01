import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/failure_message.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_list_state.dart';

class WorkflowListCubit extends Cubit<WorkflowListState> {
  WorkflowListCubit({required this.repository, this.company})
      : super(const WorkflowListState());

  final WorkflowRepository repository;
  final String? company;
  Timer? _searchTimer;
  int _loadGeneration = 0;

  void recordMutation(String id, {WorkflowDefinition? updated}) {
    if (isClosed) return;
    _loadGeneration++;
    emit(state.copyWith(items: [for (final row in state.items)
      if (row.id != id) row
      else if (updated != null && (state.filter == null || updated.status == state.filter)) updated],
      clearMessage: true));
  }

  Future<void> load({WorkflowRepository? authoritativeRepository}) async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    final source = authoritativeRepository ?? repository;
    emit(state.copyWith(status: WorkflowListLoadStatus.loading));
    try {
      final items = await source.getWorkflows(
        search: state.search,
        status: state.filter,
        company: company,
        orderBy: state.orderBy,
      );
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(
        status: WorkflowListLoadStatus.success,
        items: items,
        offlinePreview: source is OfflinePreviewAware &&
            (source as OfflinePreviewAware).isOfflinePreview,
        clearMessage: true,
      ));
    } catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(
        status: WorkflowListLoadStatus.failure,
        message: failureMessage(error),
      ));
    }
  }

  void search(String value) {
    _searchTimer?.cancel();
    emit(state.copyWith(search: value));
    _searchTimer = Timer(const Duration(milliseconds: 350), load);
  }

  Future<void> setFilter(WorkflowDefinitionStatus? value) async {
    emit(state.copyWith(filter: value, clearFilter: value == null));
    await load();
  }

  Future<void> setOrder(String value) async {
    emit(state.copyWith(orderBy: value));
    await load();
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
