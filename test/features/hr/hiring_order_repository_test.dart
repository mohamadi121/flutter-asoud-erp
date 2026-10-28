import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  late _Client client;
  late HiringOrderRepository repository;

  setUp(() {
    client = _Client();
    repository = HiringOrderRepository(client);
  });

  test('loads people and preserves the server missing-payroll state', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single;
      if (method.endsWith('list_hiring_order_people')) {
        return [
          {
            'name': 'EMP-1',
            'display_name': 'علی رضایی',
            'employee_number': '۱۰۱',
            'department': 'اداری',
            'designation': 'کارشناس',
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
            'amount': null,
            'state': 'missing',
            'message': 'اطلاعات موجود نیست',
          }
        ]
      };
    });

    final people = await repository.people(company: 'COMP-1', search: 'علی');
    final payroll = await repository.payroll(
        company: 'COMP-1', employee: 'EMP-1', effectiveDate: '2026-10-28');

    expect(people.single.displayName, 'علی رضایی');
    expect(people.single.department, 'اداری');
    expect(payroll.rows.single.isMissing, isTrue);
    expect(payroll.rows.single.message, 'اطلاعات موجود نیست');
    expect(payroll.hasMissing, isTrue);
  });

  test('listOrders, getOrder, saveOrder, sendForReview and printOrder work correctly',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single as String;
      if (method.endsWith('list_hiring_orders')) {
        return {
          'items': [
            {
              'name': 'ENTRY-1',
              'number': 'ORD-1405-001',
              'employee': 'EMP-1',
              'employee_name': 'رضا احمدی',
              'status': 'draft',
              'status_label': 'پیش‌نویس',
              'effective_date': '1405/01/01',
              'issue_date': '',
              'drafted_on': '1405/01/01',
              'revision': 1,
            }
          ]
        };
      }
      if (method.endsWith('get_hiring_order') ||
          method.endsWith('save_hiring_order')) {
        return {
          'name': 'ENTRY-1',
          'number': 'ORD-1405-001',
          'company': 'COMP-1',
          'company_name': 'شرکت نمونه',
          'employee': 'EMP-1',
          'employee_name': 'رضا احمدی',
          'employee_number': '101',
          'status': 'draft',
          'status_label': 'پیش‌نویس',
          'effective_date': '1405/01/01',
          'issue_date': '',
          'drafted_on': '1405/01/01',
          'department': 'فروش',
          'designation': 'کارشناس فروش',
          'location': 'دفتر مرکزی',
          'values': {'unit': 'فروش', 'position': 'کارشناس فروش'},
          'template_snapshot': {'articles': []},
          'payroll_snapshot': {
            'currency': 'IRR',
            'monthly_total': 150000000,
            'rows': [
              {
                'id': 'base_salary',
                'title': 'حقوق پایه',
                'period': 'monthly',
                'amount': 150000000,
                'state': 'available',
                'message': '',
              }
            ]
          },
          'revision': 1,
        };
      }
      if (method.endsWith('send_hiring_order_for_review')) {
        return {
          'name': 'ENTRY-1',
          'number': '',
          'company': 'COMP-1',
          'company_name': 'شرکت نمونه',
          'employee': 'EMP-1',
          'employee_name': 'رضا احمدی',
          'employee_number': '101',
          'status': 'pending',
          'status_label': 'در جریان',
          'effective_date': '1405/01/01',
          'issue_date': '',
          'drafted_on': '1405/01/01',
          'department': 'فروش',
          'designation': 'کارشناس فروش',
          'location': 'دفتر مرکزی',
          'values': {},
          'template_snapshot': {},
          'revision': 2,
        };
      }
      if (method.endsWith('print_hiring_order')) {
        return {
          'html': '<html><body>حکم استخدام</body></html>',
          'status': 'draft',
          'number': '—',
          'draft_banner': true,
        };
      }
      return {};
    });

    final list = await repository.listOrders(company: 'COMP-1', search: 'رضا');
    expect(list.length, 1);
    expect(list.first.isDraft, isTrue);
    expect(list.first.number, 'ORD-1405-001');

    final order = await repository.getOrder(name: 'ENTRY-1');
    expect(order.employeeName, 'رضا احمدی');
    expect(order.payrollSnapshot?.monthlyTotal, 150000000);

    final saved = await repository.saveOrder(
      company: 'COMP-1',
      requestId: 'req-1',
      employee: 'EMP-1',
      effectiveDate: '1405/01/01',
      values: {'location': 'دفتر مرکزی'},
    );
    expect(saved.name, 'ENTRY-1');

    final reviewed = await repository.sendForReview(
        name: 'ENTRY-1', revision: 1, requestId: 'rev-1');
    expect(reviewed.isPending, isTrue);
    expect(reviewed.statusLabel, 'در جریان');

    final printDoc = await repository.printOrder(name: 'ENTRY-1');
    expect(printDoc.draftBanner, isTrue);
    expect(printDoc.html, contains('حکم استخدام'));
  });

  test('template lifecycle methods (get, save, publish)', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.single as String;
      if (method.endsWith('get_hiring_order_template')) {
        return {
          'template': {
            'revision': 1,
            'articles': [
              {'id': 'art1', 'title': 'ماده ۱', 'body': 'متن'}
            ]
          }
        };
      }
      if (method.endsWith('save_hiring_order_template')) {
        return {
          'revision': 2,
          'template': {'articles': []}
        };
      }
      if (method.endsWith('publish_hiring_order_template')) {
        return {
          'revision': 2,
          'template': {'articles': []}
        };
      }
      return {};
    });

    final tpl = await repository.getTemplate(company: 'COMP-1');
    expect(tpl?['revision'], 1);

    final saved = await repository.saveTemplate(
        company: 'COMP-1', revision: 1, template: {'articles': []});
    expect(saved['revision'], 2);

    final published =
        await repository.publishTemplate(company: 'COMP-1', revision: 2);
    expect(published['revision'], 2);
  });

  test('payrollCatalog loads available field references', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      return {
        'items': [
          {'field_id': 'base', 'label': 'حقوق پایه', 'type': 'Currency'},
          {'field_id': 'component.Housing', 'label': 'حق مسکن', 'type': 'Currency'},
        ]
      };
    });

    final catalog = await repository.payrollCatalog(company: 'COMP-1');
    expect(catalog.length, 2);
    expect(catalog.first['field_id'], 'base');
    expect(catalog.last['field_id'], 'component.Housing');
  });
}
