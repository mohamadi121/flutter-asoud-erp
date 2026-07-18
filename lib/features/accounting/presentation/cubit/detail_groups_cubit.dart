import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/detail_group.dart';
import '../../domain/repositories/detail_group_repository.dart';

enum DetailGroupsStatus { initial, loading, success, empty, failure }

class DetailGroupsState extends Equatable {
  const DetailGroupsState({
    this.status = DetailGroupsStatus.initial,
    this.groups = const [],
    this.message,
  });
  final DetailGroupsStatus status;
  final List<DetailGroup> groups;
  final String? message;
  @override
  List<Object?> get props => [status, groups, message];
}

class DetailGroupsCubit extends Cubit<DetailGroupsState> {
  DetailGroupsCubit(this._repository) : super(const DetailGroupsState());
  final DetailGroupRepository _repository;

  Future<void> load() async {
    emit(const DetailGroupsState(status: DetailGroupsStatus.loading));
    try {
      final groups = await _repository.getGroups();
      emit(DetailGroupsState(
        status: groups.isEmpty
            ? DetailGroupsStatus.empty
            : DetailGroupsStatus.success,
        groups: groups,
      ));
    } catch (_) {
      emit(const DetailGroupsState(
        status: DetailGroupsStatus.failure,
        message: 'دریافت گروه‌های تفصیلی از ERPNext ممکن نشد.',
      ));
    }
  }

  Future<void> seedDefaults() async {
    emit(const DetailGroupsState(status: DetailGroupsStatus.loading));
    try {
      final groups = await _repository.seedDefaults();
      emit(DetailGroupsState(
          status: DetailGroupsStatus.success, groups: groups));
    } catch (_) {
      emit(const DetailGroupsState(
        status: DetailGroupsStatus.failure,
        message: 'ایجاد گروه‌های پیشنهادی در ERPNext انجام نشد.',
      ));
    }
  }

  Future<bool> addGroup(String code, String title) async {
    if (!RegExp(r'^\d{3,12}$').hasMatch(code.trim()) ||
        title.trim().length < 2) {
      emit(DetailGroupsState(
        status: DetailGroupsStatus.failure,
        groups: state.groups,
        message: 'عنوان و کد ۳ تا ۱۲ رقمی گروه را بررسی کنید.',
      ));
      return false;
    }
    final current = state.groups;
    emit(
        DetailGroupsState(status: DetailGroupsStatus.loading, groups: current));
    try {
      await _repository.saveGroup(code: code.trim(), title: title.trim());
      await load();
      return true;
    } catch (_) {
      emit(DetailGroupsState(
        status: DetailGroupsStatus.failure,
        groups: current,
        message: 'ذخیره گروه تفصیلی در ERPNext انجام نشد.',
      ));
      return false;
    }
  }
}
