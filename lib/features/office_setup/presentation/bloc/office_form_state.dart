part of 'office_form_bloc.dart';

enum OfficeFormStatus { editing, invalid, submitting, success, failure }

class OfficeFormState extends Equatable {
  const OfficeFormState({
    required this.officeType,
    this.name = '',
    this.nationalId = '',
    this.economicCode = '',
    this.generateDetailCode = true,
    this.status = OfficeFormStatus.editing,
  });

  final OfficeType officeType;
  final String name;
  final String nationalId;
  final String economicCode;
  final bool generateDetailCode;
  final OfficeFormStatus status;

  bool get isValid {
    if (name.trim().length < 3) return false;
    if (officeType == OfficeType.legal && nationalId.trim().length != 11) return false;
    return true;
  }

  OfficeFormState copyWith({
    String? name,
    String? nationalId,
    String? economicCode,
    bool? generateDetailCode,
    OfficeFormStatus? status,
  }) {
    return OfficeFormState(
      officeType: officeType,
      name: name ?? this.name,
      nationalId: nationalId ?? this.nationalId,
      economicCode: economicCode ?? this.economicCode,
      generateDetailCode: generateDetailCode ?? this.generateDetailCode,
      status: status ?? OfficeFormStatus.editing,
    );
  }

  @override
  List<Object?> get props => [
        officeType,
        name,
        nationalId,
        economicCode,
        generateDetailCode,
        status,
      ];
}

