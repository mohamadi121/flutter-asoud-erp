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
        name: json['company_name'] as String? ?? json['name'] as String? ?? '',
        type: json['custom_office_type'] == 'Legal'
            ? OfficeType.legal
            : OfficeType.personal,
        fiscalYearStart:
            DateTime.tryParse(json['date_of_establishment'] as String? ?? '') ??
                DateTime.now(),
        nationalId: json['tax_id'] as String?,
        economicCode: json['custom_economic_code'] as String?,
        generateDetailCode: json['custom_generate_detail_code'] != 0,
      );

  factory OfficeModel.fromSetup(Map<String, dynamic> json) => OfficeModel(
        name: json['company'] as String? ?? '',
        type: json['office_type'] == 'Legal'
            ? OfficeType.legal
            : OfficeType.personal,
        fiscalYearStart: DateTime(DateTime.now().year,
            (json['fiscal_year_start_month'] as num?)?.toInt() ?? 1),
        nationalId: json['national_id'] as String?,
        economicCode: json['economic_code'] as String?,
        generateDetailCode: json['auto_generate_detail_code'] != false,
      );

  Map<String, dynamic> toJson() => {
        'company_name': name,
        'abbr': _abbreviation(name),
        'default_currency': 'IRR',
        'country': 'Iran',
        'date_of_establishment':
            fiscalYearStart.toIso8601String().split('T').first,
        'tax_id': nationalId,
        'custom_office_type': type == OfficeType.legal ? 'Legal' : 'Personal',
        'custom_economic_code': economicCode,
        'custom_generate_detail_code': generateDetailCode ? 1 : 0,
      };

  static String _abbreviation(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    final result = words
        .where((word) => word.isNotEmpty)
        .take(3)
        .map((word) => word[0])
        .join();
    return result.isEmpty ? 'ASD' : result.toUpperCase();
  }
}
