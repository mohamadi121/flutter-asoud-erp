import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';

part 'office_form_event.dart';
part 'office_form_state.dart';

class OfficeFormBloc extends Bloc<OfficeFormEvent, OfficeFormState> {
  OfficeFormBloc({required OfficeType officeType, required OfficeRepository repository})
      : _repository = repository,
        super(OfficeFormState(officeType: officeType)) {
    on<OfficeNameChanged>((event, emit) => emit(state.copyWith(name: event.value)));
    on<NationalIdChanged>((event, emit) => emit(state.copyWith(nationalId: event.value)));
    on<EconomicCodeChanged>((event, emit) => emit(state.copyWith(economicCode: event.value)));
    on<GenerateDetailCodeChanged>(
      (event, emit) => emit(state.copyWith(generateDetailCode: event.value)),
    );
    on<OfficeFormSubmitted>((event, emit) async {
      if (state.status == OfficeFormStatus.submitting || state.status == OfficeFormStatus.success) return;
      if (!state.isValid) {
        emit(state.copyWith(status: OfficeFormStatus.invalid));
        return;
      }
      emit(state.copyWith(status: OfficeFormStatus.submitting, clearError: true));
      try {
        await _repository.createOffice(
          Office(
            name: state.name.trim(),
            type: state.officeType,
            fiscalYearStart: DateTime.now(),
            nationalId: state.nationalId.trim().isEmpty ? null : state.nationalId.trim(),
            economicCode: state.economicCode.trim().isEmpty ? null : state.economicCode.trim(),
            generateDetailCode: state.generateDetailCode,
          ),
        );
        emit(state.copyWith(status: OfficeFormStatus.success));
      } catch (error) {
        emit(state.copyWith(status: OfficeFormStatus.failure, errorMessage: 'خطای سرور: $error'));
      }
    });
  }

  final OfficeRepository _repository;
}

