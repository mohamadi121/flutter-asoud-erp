import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/parties_repository.dart';

enum PartiesStatus { initial, loading, success, failure }

class PartiesState extends Equatable {
  const PartiesState({this.status = PartiesStatus.initial, this.items = const [], this.message});
  final PartiesStatus status;
  final List<PartyProfile> items;
  final String? message;

  @override
  List<Object?> get props => [status, items, message];
}

class PartiesCubit extends Cubit<PartiesState> {
  PartiesCubit(this._repository) : super(const PartiesState());
  final PartiesRepository _repository;

  Future<void> load({String? search}) async {
    emit(const PartiesState(status: PartiesStatus.loading));
    try {
      final items = await _repository.getParties(search: search);
      emit(PartiesState(status: PartiesStatus.success, items: items));
    } catch (error) {
      emit(PartiesState(status: PartiesStatus.failure, message: error.toString()));
    }
  }
}
