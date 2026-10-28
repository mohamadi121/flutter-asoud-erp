import 'package:asoud_erp/features/hr/data/employment_certificate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the published certificate list contract without exposing ids', () {
    final item = EmploymentCertificate.fromMap({
      'name': 'CERT-1',
      'employee_name': 'مینا رضایی',
      'employee_number': '۱۲۳',
      'number': '۱۴۰۵-۱',
      'addressee_name': 'بانک',
      'status': 'Draft',
    });
    expect(item.employeeName, 'مینا رضایی');
    expect(item.statusLabel, 'پیش‌نویس');
    expect(item.number, '۱۴۰۵-۱');
  });
}
