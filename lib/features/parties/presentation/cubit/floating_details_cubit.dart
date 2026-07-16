import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/floating_detail.dart';
import '../../domain/repositories/parties_repository.dart';

enum FloatingDetailsStatus { initial, loading, success, failure }

class FloatingDetailsState extends Equatable {
  const FloatingDetailsState({
    this.status = FloatingDetailsStatus.initial,
    this.items = const [],
    this.message,
  });

  final FloatingDetailsStatus status;
  final List<FloatingDetail> items;
  final String? message;

  @override
  List<Object?> get props => [status, items, message];
}

class FloatingDetailsCubit extends Cubit<FloatingDetailsState> {
  FloatingDetailsCubit(this._repository) : super(const FloatingDetailsState());
  final PartiesRepository _repository;

  Future<void> load({String? search}) async {
    emit(const FloatingDetailsState(status: FloatingDetailsStatus.loading));
    try {
      final items = await _repository.getFloatingDetails(search: search);
      emit(FloatingDetailsState(status: FloatingDetailsStatus.success, items: items));
    } catch (error) {
      emit(FloatingDetailsState(status: FloatingDetailsStatus.failure, message: error.toString()));
    }
  }
}
