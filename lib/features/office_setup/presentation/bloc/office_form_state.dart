part of 'office_form_bloc.dart';

enum OfficeFormStatus {
  editing,
  invalid,
  submitting,
  success,
  offlinePreview,
  failure,
}

class OfficeFormState extends Equatable {
  const OfficeFormState({
    required this.officeType,
    this.officeName = '',
    this.ownerFullName = '',
    this.registrationNumber = '',
    this.nationalId = '',
    this.activityType = '',
    this.companyType = '',
    this.hasIndependentPersonality = true,
    this.parentOffice = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.province = '',
    this.city = '',
    this.address = '',
    this.postalCode = '',
    this.fiscalYear = '',
    this.chartTemplate = '',
    this.logoName,
    this.logoBytes,
    this.description = '',
    this.status = OfficeFormStatus.editing,
    this.errors = const {},
    this.message,
    this.createdOffice,
  });

  final OfficeType officeType;
  final String officeName, ownerFullName, registrationNumber, nationalId;
  final String activityType, companyType, parentOffice, phone, email, website;
  final String province, city, address, postalCode, fiscalYear, chartTemplate;
  final bool hasIndependentPersonality;
  final String? logoName;
  final Uint8List? logoBytes;
  final String description;
  final OfficeFormStatus status;
  final Map<String, String> errors;
  final String? message;
  final Office? createdOffice;

  bool get isDirty =>
      [
        officeName,
        ownerFullName,
        registrationNumber,
        nationalId,
        activityType,
        companyType,
        parentOffice,
        phone,
        email,
        website,
        province,
        city,
        address,
        postalCode,
        fiscalYear,
        chartTemplate,
        description
      ].any((value) => value.trim().isNotEmpty) ||
      logoBytes != null;

  OfficeFormState copyWith({
    OfficeType? officeType,
    String? officeName,
    String? ownerFullName,
    String? registrationNumber,
    String? nationalId,
    String? activityType,
    String? companyType,
    bool? hasIndependentPersonality,
    String? parentOffice,
    String? phone,
    String? email,
    String? website,
    String? province,
    String? city,
    String? address,
    String? postalCode,
    String? fiscalYear,
    String? chartTemplate,
    String? logoName,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? description,
    OfficeFormStatus? status,
    Map<String, String>? errors,
    String? message,
    bool clearMessage = false,
    Office? createdOffice,
  }) =>
      OfficeFormState(
        officeType: officeType ?? this.officeType,
        officeName: officeName ?? this.officeName,
        ownerFullName: ownerFullName ?? this.ownerFullName,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        nationalId: nationalId ?? this.nationalId,
        activityType: activityType ?? this.activityType,
        companyType: companyType ?? this.companyType,
        hasIndependentPersonality:
            hasIndependentPersonality ?? this.hasIndependentPersonality,
        parentOffice: parentOffice ?? this.parentOffice,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        website: website ?? this.website,
        province: province ?? this.province,
        city: city ?? this.city,
        address: address ?? this.address,
        postalCode: postalCode ?? this.postalCode,
        fiscalYear: fiscalYear ?? this.fiscalYear,
        chartTemplate: chartTemplate ?? this.chartTemplate,
        logoName: clearLogo ? null : logoName ?? this.logoName,
        logoBytes: clearLogo ? null : logoBytes ?? this.logoBytes,
        description: description ?? this.description,
        status: status ?? OfficeFormStatus.editing,
        errors: errors ?? this.errors,
        message: clearMessage ? null : message ?? this.message,
        createdOffice: createdOffice ?? this.createdOffice,
      );

  @override
  List<Object?> get props => [
        officeType,
        officeName,
        ownerFullName,
        registrationNumber,
        nationalId,
        activityType,
        companyType,
        hasIndependentPersonality,
        parentOffice,
        phone,
        email,
        website,
        province,
        city,
        address,
        postalCode,
        fiscalYear,
        chartTemplate,
        logoName,
        logoBytes,
        description,
        status,
        errors,
        message,
        createdOffice
      ];
}
