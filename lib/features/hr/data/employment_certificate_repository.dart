import '../../../core/network/frappe_client.dart';

class EmploymentCertificate {
  const EmploymentCertificate({required this.name, required this.employeeName, required this.employeeNumber, required this.number, required this.addresseeName, required this.status});
  factory EmploymentCertificate.fromMap(Map<String, dynamic> map) => EmploymentCertificate(
        name: map['name']?.toString() ?? '',
        employeeName: map['employee_name']?.toString().trim().isNotEmpty == true ? map['employee_name'].toString() : 'پرسنل منتسب',
        employeeNumber: map['employee_number']?.toString() ?? '',
        number: map['number']?.toString() ?? '—',
        addresseeName: map['addressee_name']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Draft',
      );
  final String name, employeeName, employeeNumber, number, addresseeName, status;
  String get statusLabel => switch (status) {'Draft' => 'پیش‌نویس', 'Final' => 'نهایی', _ => 'در جریان'};
}

class EmploymentCertificateRepository {
  EmploymentCertificateRepository(this._client);
  final FrappeApiClient _client;
  static const _module = 'asoud_erp.api.v1.employment_certificates';

  Future<({List<EmploymentCertificate> items, int total})> list({required String company, String query = '', String status = '', int start = 0}) async {
    final raw = Map<String, dynamic>.from(await _client.callAsoudMethod('$_module.list_certificates', data: {'company': company, 'query': query, 'status': status, 'start': start, 'page_length': 20}) as Map);
    final items = (raw['items'] as List? ?? const []).map((row) => EmploymentCertificate.fromMap(Map<String, dynamic>.from(row as Map))).toList();
    return (items: items, total: raw['total'] is int ? raw['total'] as int : items.length);
  }
}
