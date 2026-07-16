import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/detail_group.dart';
import '../../domain/entities/floating_detail.dart';
import '../../domain/repositories/parties_repository.dart';

enum DetailFormStatus { loading, editing, saving, success, failure, invalid }

class FloatingDetailFormState extends Equatable {
  const FloatingDetailFormState({
    this.status = DetailFormStatus.loading,
    this.groups = const [],
    this.title = '',
    this.type = 'Customer',
    this.groupCode,
    this.manualCode = '',
    this.autoCode = true,
    this.saved,
    this.message,
  });

  final DetailFormStatus status;
  final List<DetailGroup> groups;
  final String title;
  final String type;
  final String? groupCode;
  final String manualCode;
  final bool autoCode;
  final FloatingDetail? saved;
  final String? message;

  FloatingDetailFormState copyWith({
    DetailFormStatus? status,
    List<DetailGroup>? groups,
    String? title,
    String? type,
    String? groupCode,
    String? manualCode,
    bool? autoCode,
    FloatingDetail? saved,
    String? message,
  }) =>
      FloatingDetailFormState(
        status: status ?? DetailFormStatus.editing,
        groups: groups ?? this.groups,
        title: title ?? this.title,
        type: type ?? this.type,
        groupCode: groupCode ?? this.groupCode,
        manualCode: manualCode ?? this.manualCode,
        autoCode: autoCode ?? this.autoCode,
        saved: saved ?? this.saved,
        message: message,
      );

  @override
  List<Object?> get props => [status, groups, title, type, groupCode, manualCode, autoCode, saved, message];
}

class FloatingDetailFormCubit extends Cubit<FloatingDetailFormState> {
  FloatingDetailFormCubit(this._repository) : super(const FloatingDetailFormState());
  final PartiesRepository _repository;

  Future<void> initialize() async {
    try {
      final groups = await _repository.getDetailGroups();
      emit(state.copyWith(status: DetailFormStatus.editing, groups: groups));
    } catch (error) {
      emit(state.copyWith(status: DetailFormStatus.failure, message: error.toString()));
    }
  }

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setType(String value) => emit(state.copyWith(type: value));
  void setGroup(String? value) => emit(state.copyWith(groupCode: value));
  void setManualCode(String value) => emit(state.copyWith(manualCode: value));
  void setAutoCode(bool value) => emit(state.copyWith(autoCode: value));

  Future<void> submit() async {
    if (state.title.trim().length < 3 || state.groupCode == null || (!state.autoCode && state.manualCode.isEmpty)) {
      emit(state.copyWith(status: DetailFormStatus.invalid));
      return;
    }
    emit(state.copyWith(status: DetailFormStatus.saving));
    try {
      final saved = await _repository.createFloatingDetail(
        FloatingDetail(
          id: '',
          code: state.autoCode ? '' : state.manualCode.trim(),
          title: state.title.trim(),
          type: state.type,
          groupCode: state.groupCode!,
        ),
      );
      emit(state.copyWith(status: DetailFormStatus.success, saved: saved));
    } catch (error) {
      emit(state.copyWith(status: DetailFormStatus.failure, message: error.toString()));
    }
  }
}
