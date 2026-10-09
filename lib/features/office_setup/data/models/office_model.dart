import '../../../../core/utils/jalali_date.dart';
import '../../domain/entities/office.dart';

class OfficeModel extends Office {
  const OfficeModel({
    required super.name,
    required super.type,
    required super.fiscalYearStart,
    super.nationalId,
    super.economicCode,
    super.generateDetailCode,
    super.ownerFullName,
    super.registrationNumber,
    super.activityType,
    super.companyType,
    super.parentOffice,
    super.phone,
    super.email,
    super.website,
    super.province,
    super.city,
    super.address,
    super.postalCode,
    super.fiscalYear,
    super.chartTemplate,
    super.description,
    super.lastSyncedAt,
    super.setupComplete,
  });

  factory OfficeModel.fromEntity(Office office) => OfficeModel(
        name: office.name,
        type: office.type,
        fiscalYearStart: office.fiscalYearStart,
        nationalId: office.nationalId,
        economicCode: office.economicCode,
        generateDetailCode: office.generateDetailCode,
        ownerFullName: office.ownerFullName,
        registrationNumber: office.registrationNumber,
        activityType: office.activityType,
        companyType: office.companyType,
        parentOffice: office.parentOffice,
        phone: office.phone,
        email: office.email,
        website: office.website,
        province: office.province,
        city: office.city,
        address: office.address,
        postalCode: office.postalCode,
        fiscalYear: office.fiscalYear,
        chartTemplate: office.chartTemplate,
        description: office.description,
        lastSyncedAt: office.lastSyncedAt,
        setupComplete: office.setupComplete,
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
        ownerFullName: json['owner_full_name'] as String?,
        registrationNumber: json['registration_number'] as String?,
        activityType: json['activity_type'] as String?,
        companyType: json['company_type'] as String?,
        parentOffice: json['parent_office'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        website: json['website'] as String?,
        province: _provinceToPersian(json['province'] as String?),
        city: _cityToPersian(json['city'] as String?),
        address: json['address'] as String?,
        postalCode: json['postal_code'] as String?,
        fiscalYear: _fiscalYearToPersian(json['fiscal_year']),
        chartTemplate:
            _chartTemplateToPersian(json['chart_template'] as String?),
        description: json['description'] as String?,
        lastSyncedAt: DateTime.tryParse(json['modified']?.toString() ?? ''),
        setupComplete: json['complete'] == true ||
            json['complete'] == 1 ||
            json['setup_complete'] == true ||
            json['setup_complete'] == 1 ||
            json['is_setup_complete'] == true ||
            json['is_setup_complete'] == 1,
      );

  static String? _chartTemplateToPersian(String? value) => switch (value) {
        'Iran Standard' || 'استاندارد ایران' => 'استاندارد ایران',
        'Service' || 'خدماتی' => 'خدماتی',
        'Commercial' || 'بازرگانی' => 'بازرگانی',
        'Manufacturing' || 'تولیدی' => 'تولیدی',
        _ => value,
      };

  static String? _provinceToPersian(String? value) => switch (value) {
        'Tehran' => 'تهران',
        'Isfahan' => 'اصفهان',
        'Fars' => 'فارس',
        'Razavi Khorasan' => 'خراسان رضوی',
        'East Azerbaijan' => 'آذربایجان شرقی',
        _ => value,
      };

  static String? _cityToPersian(String? value) => switch (value) {
        'Tehran' => 'تهران',
        'Rey' => 'ری',
        'Shemiranat' => 'شمیرانات',
        'Isfahan' => 'اصفهان',
        'Kashan' => 'کاشان',
        'Najafabad' => 'نجف‌آباد',
        'Shiraz' => 'شیراز',
        'Marvdasht' => 'مرودشت',
        'Kazerun' => 'کازرون',
        'Mashhad' => 'مشهد',
        'Neyshabur' => 'نیشابور',
        'Sabzevar' => 'سبزوار',
        'Tabriz' => 'تبریز',
        'Maragheh' => 'مراغه',
        'Marand' => 'مرند',
        _ => value,
      };

  static String? _fiscalYearToPersian(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return toPersianDigits(str);
  }

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
