import '../../domain/entities/office.dart';

class OfficeModel extends Office {
  const OfficeModel({
    required super.name,
    required super.type,
    required super.fiscalYearStart,
    super.nationalId,
    super.economicCode,
    super.generateDetailCode,
  });

  factory OfficeModel.fromEntity(Office office) => OfficeModel(
        name: office.name,
        type: office.type,
        fiscalYearStart: office.fiscalYearStart,
        nationalId: office.nationalId,
        economicCode: office.economicCode,
        generateDetailCode: office.generateDetailCode,
      );

  factory OfficeModel.fromJson(Map<String, dynamic> json) => OfficeModel(
        name: json['company'] as String? ?? json['company_name'] as String? ?? '',
        type: json['office_type'] == 'Legal' ? OfficeType.legal : OfficeType.personal,
        fiscalYearStart: DateTime.now(),
        nationalId: json['national_id'] as String?,
        economicCode: json['economic_code'] as String?,
        generateDetailCode: json['auto_generate_detail_code'] != false,
      );

  Map<String, dynamic> toSetupJson() => {
        'company_name': name,
        'office_type': type == OfficeType.legal ? 'Legal' : 'Personal',
        if (nationalId?.isNotEmpty ?? false) 'national_id': nationalId,
        if (economicCode?.isNotEmpty ?? false) 'economic_code': economicCode,
        'auto_generate_detail_code': generateDetailCode ? 1 : 0,
      };

  OfficeModel copyWithName(String value) => OfficeModel(
        name: value,
        type: type,
        fiscalYearStart: fiscalYearStart,
        nationalId: nationalId,
        economicCode: economicCode,
        generateDetailCode: generateDetailCode,
      );
}

