import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';

part 'offices_state.dart';

class OfficesCubit extends Cubit<OfficesState> {
  OfficesCubit(
      {required OfficeRepository repository, OfficesState? initialState})
      : _repository = repository,
        super(initialState ?? const OfficesState());

  final OfficeRepository _repository;

  Future<void> load(
      {Office? fallbackOffice, bool showCreatedBanner = false}) async {
    emit(state.copyWith(status: OfficesStatus.loading));
    try {
      final results = await Future.wait([
        _repository.listOffices(),
        _repository.getDefaultOffice(),
      ]);
      final offices = results[0] as List<Office>;
      final defaultOffice = results[1] as Office? ?? fallbackOffice;
      emit(OfficesState(
        status: offices.isEmpty ? OfficesStatus.empty : OfficesStatus.success,
        offices: offices.isEmpty && fallbackOffice != null
            ? [fallbackOffice]
            : offices,
        defaultOffice: defaultOffice,
        showCreatedBanner: showCreatedBanner,
      ));
    } on ApiException catch (error) {
      emit(OfficesState(status: OfficesStatus.error, message: error.message));
    } catch (_) {
      emit(const OfficesState(
          status: OfficesStatus.error,
          message: 'دریافت فهرست دفترها ممکن نشد.'));
    }
  }

  Future<void> retry() => load();

  void search(String value) => emit(state.copyWith(query: value));
  void dismissCreatedBanner() => emit(state.copyWith(showCreatedBanner: false));
}
