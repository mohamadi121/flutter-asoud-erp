part of 'office_form_bloc.dart';

sealed class OfficeFormEvent extends Equatable {
  const OfficeFormEvent();
  @override
  List<Object?> get props => [];
}

final class OfficeTypeChanged extends OfficeFormEvent {
  const OfficeTypeChanged(this.value);
  final OfficeType value;
  @override
  List<Object?> get props => [value];
}

final class OfficeFieldChanged extends OfficeFormEvent {
  const OfficeFieldChanged(this.field, this.value);
  final String field;
  final Object? value;
  @override
  List<Object?> get props => [field, value];
}

final class OfficeLogoChanged extends OfficeFormEvent {
  const OfficeLogoChanged({this.name, this.bytes});
  final String? name;
  final Uint8List? bytes;
  @override
  List<Object?> get props => [name, bytes];
}

final class OfficeFormSubmitted extends OfficeFormEvent {
  const OfficeFormSubmitted();
}
