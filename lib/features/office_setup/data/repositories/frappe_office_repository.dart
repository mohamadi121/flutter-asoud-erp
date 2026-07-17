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
      },
    );
    if (data is! Map) throw const ApiException.protocol();
    return OfficeModel.fromSetup(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<Office>> listOffices() async {
    final rows =
        await _client.getResourceList('ASOUD Company Setup', queryParameters: {
      'fields':
          '["company","office_type","national_id","economic_code","fiscal_year_start_month","auto_generate_detail_code"]',
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
