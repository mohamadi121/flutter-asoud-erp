import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/office.dart';
import '../../domain/repositories/office_repository.dart';
import '../models/office_model.dart';

class FrappeOfficeRepository implements OfficeRepository {
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
        'email': office.email,
        'website': office.website,
        'province': office.province,
        'city': office.city,
        'address': office.address,
        'postal_code': office.postalCode,
        'fiscal_year': office.fiscalYear,
        'chart_template': office.chartTemplate,
        'description': office.description,
      };

  @override
  Future<List<Office>> listOffices() async {
    final rows =
        await _client.getResourceList('ASOUD Company Setup', queryParameters: {
      'fields':
          '["company","office_type","national_id","economic_code","owner_full_name","registration_number","activity_type","company_type","parent_office","phone","email","website","province","city","address","postal_code","fiscal_year","fiscal_year_start_month","chart_template","description","auto_generate_detail_code","modified"]',
      'limit_page_length': 100,
      'order_by': 'modified desc',
    });
    return rows.map(OfficeModel.fromSetup).toList(growable: false);
  }

  @override
  Future<Office?> getDefaultOffice() async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.setup.get_setup_status',
    );
    if (data is! Map) throw const ApiException.protocol();
    final values = Map<String, dynamic>.from(data);
    if (values['company'] == null) return null;
    return OfficeModel.fromSetup(values);
  }
}
