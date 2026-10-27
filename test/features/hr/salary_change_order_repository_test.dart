import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/salary_change_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  late _Client client;
  late SalaryChangeOrderRepository repository;

  setUp(() {
    client = _Client();
    repository = SalaryChangeOrderRepository(client);
  });

  test('loads people and preserves missing previous payroll state', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single as String;
      if (method.endsWith('list_salary_change_order_people')) {
        return [
          {
            'name': 'EMP-1',
            'display_name': 'سهراب سپهری',
            'employee_number': '۱۰۲',
            'department': 'فنی',
            'designation': 'مهندس نرم‌افزار',
          }
        ];
      }
      return {
        'currency': 'IRR',
        'rows': [
          {
            'id': 'base_salary',
            'title': 'حقوق پایه',
            'period': 'monthly',
            'old_ref': 'payroll.base_salary',
            'new_ref': 'document.new.base_salary',
            'previous_amount': null,
            'state': 'missing',
            'message': 'اطلاعات موجود نیست',
          }
        ]
      };
    });

    final people = await repository.people(company: 'COMP-1', search: 'سهراب');
    final payroll = await repository.payroll(
      company: 'COMP-1',
      employee: 'EMP-1',
      effectiveDate: '1405/08/01',
    );

    expect(people.single.displayName, 'سهراب سپهری');
    expect(people.single.employeeNumber, '۱۰۲');
    expect(payroll.rows.single.isMissing, isTrue);
    expect(payroll.rows.single.message, 'اطلاعات موجود نیست');
  });

  test(
      'order lifecycle: list, get, save draft, send review, approve, and apply to payroll',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single as String;
      if (method.endsWith('list_salary_change_orders')) {
        return {
          'items': [
            {
              'name': 'ENTRY-1',
              'number': 'SAL-1405-001',
              'employee': 'EMP-1',
              'employee_name': 'احمد شاملو',
              'status': 'final',
              'status_label': 'نهایی',
              'application_status': 'not_applied',
              'application_status_label': 'اعمال‌نشده',
              'effective_date': '1405/08/01',
              'issue_date': '1405/08/05',
              'drafted_on': '1405/08/01',
              'reason': 'annual',
              'reason_label': 'افزایش سالانه',
              'revision': 3,
            }
          ]
        };
      }
      if (method.endsWith('get_salary_change_order') ||
          method.endsWith('save_salary_change_order')) {
        return {
          'name': 'ENTRY-1',
          'number': 'SAL-1405-001',
          'company': 'COMP-1',
          'company_name': 'شرکت تابان',
          'employee': 'EMP-1',
          'employee_name': 'احمد شاملو',
          'employee_number': '101',
          'status': 'draft',
          'status_label': 'پیش‌نویس',
          'application_status': 'not_applied',
          'application_status_label': 'اعمال‌نشده',
          'effective_date': '1405/08/01',
          'issue_date': '',
          'drafted_on': '1405/08/01',
          'reason': 'annual',
          'reason_label': 'افزایش سالانه',
          'department': 'مهندسی',
          'designation': 'مدیر فنی',
          'values': {},
          'comparison_table': {
            'monthly_previous_total': 200000000,
            'monthly_new_total': 250000000,
            'monthly_difference': 50000000,
            'rows': [
              {
                'id': 'base_salary',
                'title': 'حقوق پایه',
                'period': 'monthly',
                'period_label': 'ماهانه',
                'old_ref': 'payroll.base_salary',
                'new_ref': 'document.new.base_salary',
                'previous_amount': 200000000,
                'new_amount': 250000000,
                'difference': 50000000,
                'percent_change': 25.0,
                'percent_label': '+۲۵.۰۰٪',
                'state': 'available',
              }
            ],
          },
          'template_snapshot': {'articles': []},
          'revision': 1,
        };
      }
      if (method.endsWith('send_salary_change_order_for_review')) {
        return {
          'name': 'ENTRY-1',
          'number': '',
          'status': 'pending',
          'status_label': 'در جریان',
          'application_status': 'not_applied',
          'application_status_label': 'اعمال‌نشده',
          'employee': 'EMP-1',
          'employee_name': 'احمد شاملو',
          'revision': 2,
        };
      }
      if (method.endsWith('approve_salary_change_order')) {
        return {
          'name': 'ENTRY-1',
          'number': 'SAL-1405-001',
          'status': 'final',
          'status_label': 'نهایی',
          'application_status': 'not_applied',
          'application_status_label': 'اعمال‌نشده',
          'employee': 'EMP-1',
          'employee_name': 'احمد شاملو',
          'revision': 3,
        };
      }
      if (method.endsWith('apply_salary_change_order_to_payroll')) {
        return {
          'name': 'ENTRY-1',
          'number': 'SAL-1405-001',
          'status': 'final',
          'status_label': 'نهایی',
          'application_status': 'applied',
          'application_status_label': 'اعمال‌شده',
          'employee': 'EMP-1',
          'employee_name': 'احمد شاملو',
          'revision': 4,
        };
      }
      if (method.endsWith('print_salary_change_order')) {
        return {
          'html': '<html><body>حکم تغییر حقوق</body></html>',
          'status': 'final',
          'number': 'SAL-1405-001',
          'draft_banner': false,
        };
      }
      return {};
    });

    final list = await repository.listOrders(company: 'COMP-1');
    expect(list.length, 1);
    expect(list.first.isFinal, isTrue);
    expect(list.first.isApplied, isFalse);

    final detail = await repository.getOrder(name: 'ENTRY-1');
    expect(detail.comparisonRows.single.percentChange, 25.0);
    expect(detail.monthlyDifference, 50000000);

    final saved = await repository.saveOrder(
      company: 'COMP-1',
      requestId: 'req-1',
      employee: 'EMP-1',
      effectiveDate: '1405/08/01',
      reason: 'annual',
      comparisonRows: [],
    );
    expect(saved.isDraft, isTrue);

    final reviewed = await repository.sendForReview(
      name: 'ENTRY-1',
      revision: 1,
      requestId: 'rev-1',
    );
    expect(reviewed.isPending, isTrue);

    final approved = await repository.approveOrder(
      name: 'ENTRY-1',
      revision: 2,
      requestId: 'app-1',
    );
    expect(approved.isFinal, isTrue);
    expect(approved.number, 'SAL-1405-001');

    final applied = await repository.applyToPayroll(
      name: 'ENTRY-1',
      operationId: 'op-1',
    );
    expect(applied.isApplied, isTrue);
    expect(applied.applicationStatusLabel, 'اعمال‌شده');

    final printDoc = await repository.printOrder(name: 'ENTRY-1');
    expect(printDoc.draftBanner, isFalse);
    expect(printDoc.html, contains('حکم تغییر حقوق'));
  });
}
