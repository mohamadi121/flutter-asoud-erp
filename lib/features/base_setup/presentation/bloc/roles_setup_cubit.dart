import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/repositories/setup_repository.dart';

enum RolesSetupStatus { editing, saving, success, failure }

class RolesSetupState extends Equatable {
  const RolesSetupState({
    this.selected = const {'System Manager', 'Accounts Manager'},
    this.status = RolesSetupStatus.editing,
    this.errorMessage,
  });
  final Set<String> selected;
  final RolesSetupStatus status;
  final String? errorMessage;

  RolesSetupState copyWith({Set<String>? selected, RolesSetupStatus? status, String? errorMessage}) =>
      RolesSetupState(selected: selected ?? this.selected, status: status ?? RolesSetupStatus.editing, errorMessage: errorMessage);

  @override
  List<Object?> get props => [selected, status, errorMessage];
}

class RolesSetupCubit extends Cubit<RolesSetupState> {
  RolesSetupCubit(this._repository, this._company) : super(const RolesSetupState());
  final SetupRepository _repository;
  final String _company;

  void toggle(String role, bool selected) {
    if (role == 'System Manager' || state.status == RolesSetupStatus.saving) return;
    final values = {...state.selected};
    selected ? values.add(role) : values.remove(role);
    emit(state.copyWith(selected: values));
  }

  Future<void> submit() async {
    if (state.status == RolesSetupStatus.saving || state.status == RolesSetupStatus.success) return;
    emit(state.copyWith(status: RolesSetupStatus.saving));
    try {
      await _repository.saveEnabledRoles(_company, state.selected);
      emit(state.copyWith(status: RolesSetupStatus.success));
    } catch (error) {
      emit(state.copyWith(status: RolesSetupStatus.failure, errorMessage: 'خطای سرور: $error'));
    }
  }
}
