import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingClient extends Fake implements FrappeApiClient {
  Map<String, dynamic>? sent;

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'employee@example.com', fullName: 'کارمند', roles: ['Employee']);

  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    if (method.endsWith('employee_schedule')) sent = data;
    return {'message': {'ok': true, 'data': <dynamic>[], 'meta': {'api_version': 'v1'}}};
  }
}

void main() {
  test('برنامه همکار همراه با فرم و کلید فیلد درخواست می‌شود', () async {
    final client = _CapturingClient();
    await FormRepository(client, 'شرکت آزمون').employeeSchedule(
      fromDate: '2026-10-23', toDate: '2026-10-23',
      employee: 'EMP-002', form: 'FORM-1', field: 'exchange_colleague');
    expect(client.sent, containsPair('form', 'FORM-1'));
    expect(client.sent, containsPair('field', 'exchange_colleague'));
    expect(client.sent, containsPair('employee', 'EMP-002'));
  });

  test('برنامه خود کاربر بدون فرم و فیلد درخواست می‌شود', () async {
    final client = _CapturingClient();
    await FormRepository(client, 'شرکت آزمون').employeeSchedule(
      fromDate: '2026-10-23', toDate: '2026-10-23', form: 'FORM-1');
    expect(client.sent!.keys, unorderedEquals(['company', 'from_date', 'to_date']));
  });
}
