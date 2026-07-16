part of 'office_form_bloc.dart';

sealed class OfficeFormEvent extends Equatable {
  const OfficeFormEvent();

  @override
  List<Object?> get props => [];
}

final class OfficeNameChanged extends OfficeFormEvent {
  const OfficeNameChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

final class NationalIdChanged extends OfficeFormEvent {
  const NationalIdChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

final class EconomicCodeChanged extends OfficeFormEvent {
  const EconomicCodeChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

final class GenerateDetailCodeChanged extends OfficeFormEvent {
  const GenerateDetailCodeChanged(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

final class OfficeFormSubmitted extends OfficeFormEvent {
  const OfficeFormSubmitted();
}

