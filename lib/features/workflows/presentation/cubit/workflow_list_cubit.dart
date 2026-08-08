import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

part 'workflow_list_state.dart';

class WorkflowListCubit extends Cubit<WorkflowListState> {
  WorkflowListCubit({required this.repository, this.company})
      : super(const WorkflowListState());

  final WorkflowRepository repository;
  final String? company;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(status: WorkflowListLoadStatus.loading));
    try {
      final items = await repository.getWorkflows(
        search: state.search,
        status: state.filter,
        company: company,
        orderBy: state.orderBy,
      );
      emit(state.copyWith(
        status: WorkflowListLoadStatus.success,
        items: items,
        offlinePreview: repository is OfflinePreviewAware &&
            (repository as OfflinePreviewAware).isOfflinePreview,
        clearMessage: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WorkflowListLoadStatus.failure,
        message: 'دریافت فرایندها از ERPNext ممکن نشد.',
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
