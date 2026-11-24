import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../models/office_model.dart';

class FrappeOfficeRepository implements OfficeRepository, FirstOfficeRepository {
  const FrappeOfficeRepository(this._client);

  final FrappeApiClient _client;

  @override
  Future<Office> createOffice(Office office) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.setup.save_office',
      data: {
        'office_type': office.type == OfficeType.legal ? 'Legal' : 'Personal',
        'company_name': office.name,
        'national_id': office.nationalId,
        'economic_code': office.economicCode,
        'auto_generate_detail_code': office.generateDetailCode ? 1 : 0,
        ..._details(office),
      },
    );
    if (data is! Map) throw const ApiException.protocol();
    return OfficeModel.fromSetup(Map<String, dynamic>.from(data));
  }

  /// `onboarding.create_first_office`: same arguments as `save_office`, answer
  /// `{created, already_exists, office}`. Online only (never queued), and
  /// idempotent: an existing office is returned instead of a second one.
  @override
  Future<Office> createFirstOffice(Office office) async {
    final body = await _client.callMethod(
      'asoud_erp.api.v1.onboarding.create_first_office',
      data: {
        'office_type': office.type == OfficeType.legal ? 'Legal' : 'Personal',
        'company_name': office.name,
        'national_id': office.nationalId,
        'economic_code': office.economicCode,
        'auto_generate_detail_code': office.generateDetailCode ? 1 : 0,
        ..._details(office),
      },
    );
    final envelope = body['message'];
    final data = envelope is Map ? envelope['data'] : null;
    final saved = data is Map ? data['office'] : null;
    if (envelope is! Map || envelope['ok'] != true || saved is! Map) {
      throw const ApiException.protocol();
    }
    return OfficeModel.fromSetup(Map<String, dynamic>.from(saved));
  }

  @override
  Future<Office> updateOffice(String id, Office office) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.setup.save_office',
      data: {
        'company': id,
        'office_type': office.type == OfficeType.legal ? 'Legal' : 'Personal',
        'company_name': office.name,
        'national_id': office.nationalId,
        'economic_code': office.economicCode,
        'auto_generate_detail_code': office.generateDetailCode ? 1 : 0,
        ..._details(office),
      },
    );
    if (data is! Map) throw const ApiException.protocol();
    return OfficeModel.fromSetup(Map<String, dynamic>.from(data));
  }

  static Map<String, dynamic> _details(Office office) => {
        'owner_full_name': office.ownerFullName,
        'registration_number': office.registrationNumber,
        'activity_type': office.activityType,
        'company_type': office.companyType,
        'parent_office': office.parentOffice,
        'phone': office.phone,
        'landline': office.landline,
        'email': office.email,
        'website': office.website,
        'province': office.province,
        'city': office.city,
        'address': office.address,
        'postal_code': office.postalCode,
        'fiscal_year': office.fiscalYear,
        'chart_template': _chartTemplateToBackend(office.chartTemplate),
        'description': office.description,
      };

  static String? _chartTemplateToBackend(String? value) => switch (value) {
        'استاندارد ایران' || 'Iran Standard' => 'Iran Standard',
        'خدماتی' || 'Service' => 'Service',
        'بازرگانی' || 'Commercial' => 'Commercial',
        'تولیدی' || 'Manufacturing' => 'Manufacturing',
        _ => value == null || value.isEmpty ? null : value,
      };

  @override
  Future<List<Office>> listOffices() async {
    final data = await _client.callAsoudMethod('asoud_erp.api.v1.setup.list_offices');
    if (data is! Map || data['offices'] is! List) throw const ApiException.protocol();
    return (data['offices'] as List).map((row) =>
        OfficeModel.fromSetup(Map<String, dynamic>.from(row as Map))).toList(growable: false);
  }

  @override
  Future<Office?> getDefaultOffice() async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.setup.list_offices',
    );
    if (data is! Map) throw const ApiException.protocol();
    final rows = data['offices'];
    if (rows is! List) throw const ApiException.protocol();
    for (final row in rows.whereType<Map>()) {
      if (row['company'] == data['selected_office']) {
        return OfficeModel.fromSetup(Map<String, dynamic>.from(row));
      }
    }
    return null;
  }

  @override
  Future<Office> setDefaultOffice(Office office) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.setup.set_default_office',
      data: {'company': office.name},
    );
    if (data is! Map) throw const ApiException.protocol();
    return OfficeModel.fromSetup(Map<String, dynamic>.from(data));
  }
}
