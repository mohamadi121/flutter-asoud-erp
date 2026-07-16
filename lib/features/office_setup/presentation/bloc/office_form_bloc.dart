import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/office.dart';

part 'office_form_event.dart';
part 'office_form_state.dart';

class OfficeFormBloc extends Bloc<OfficeFormEvent, OfficeFormState> {
  OfficeFormBloc({required OfficeType officeType})
      : super(OfficeFormState(officeType: officeType)) {
    on<OfficeNameChanged>((event, emit) => emit(state.copyWith(name: event.value)));
    on<NationalIdChanged>((event, emit) => emit(state.copyWith(nationalId: event.value)));
    on<EconomicCodeChanged>((event, emit) => emit(state.copyWith(economicCode: event.value)));
    on<GenerateDetailCodeChanged>(
      (event, emit) => emit(state.copyWith(generateDetailCode: event.value)),
    );
    on<OfficeFormSubmitted>((event, emit) {
      if (!state.isValid) {
        emit(state.copyWith(status: OfficeFormStatus.invalid));
        return;
      }
      emit(state.copyWith(status: OfficeFormStatus.success));
    });
  }
}

