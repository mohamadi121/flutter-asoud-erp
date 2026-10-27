import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  test('loads people and preserves the server missing-payroll state', () async {
    final client = _Client();
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single;
      if (method.endsWith('list_hiring_order_people')) {
        return [
          {'name': 'EMP-1', 'display_name': 'علی رضایی', 'employee_number': '۱۰۱'}
        ];
      }
      return {
        'currency': 'IRR',
        'rows': [
          {'id': 'base_salary', 'title': 'حقوق پایه', 'period': 'monthly', 'amount': null,
           'state': 'missing', 'message': 'اطلاعات موجود نیست'}
        ]
      };
    });
    final repository = HiringOrderRepository(client);

    final people = await repository.people(company: 'COMP-1', search: 'علی');
    final payroll = await repository.payroll(company: 'COMP-1', employee: 'EMP-1', effectiveDate: '2026-10-28');

    expect(people.single.displayName, 'علی رضایی');
    expect(payroll.rows.single.isMissing, isTrue);
    expect(payroll.rows.single.message, 'اطلاعات موجود نیست');
    verify(() => client.callAsoudMethod('asoud_erp.api.v1.hiring_orders.list_hiring_order_people',
        data: {'company': 'COMP-1', 'search': 'علی'})).called(1);
  });
}
