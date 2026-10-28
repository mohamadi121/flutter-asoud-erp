import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/hiring_orders_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements HiringOrderRepository {}

void main() {
  late _Repository repository;
  late HiringOrdersCubit cubit;

  setUp(() {
    repository = _Repository();
    cubit = HiringOrdersCubit(repository: repository, company: 'COMP-1');
  });

  tearDown(() => cubit.close());

  test('initial state has correct defaults', () {
    expect(cubit.state.status, HiringOrdersStatus.initial);
    expect(cubit.state.orders, isEmpty);
    expect(cubit.state.statusFilter, 'all');
  });

  test('load() emits loaded state on success', () async {
    const summary = HiringOrderSummary(
      name: 'ENTRY-1',
      number: 'ORD-1405-001',
      employee: 'EMP-1',
      employeeName: 'علی رضایی',
      status: 'draft',
      statusLabel: 'پیش‌نویس',
      effectiveDate: '1405/01/01',
      issueDate: '',
      draftedOn: '1405/01/01',
      revision: 1,
    );
    when(() => repository.listOrders(company: 'COMP-1', search: '', status: ''))
        .thenAnswer((_) async => [summary]);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => {'revision': 1});

    await cubit.load();

    expect(cubit.state.status, HiringOrdersStatus.loaded);
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.employeeName, 'علی رضایی');
    expect(cubit.state.publishedTemplate?['revision'], 1);
  });

  test('load() emits error state on failure', () async {
    when(() => repository.listOrders(company: 'COMP-1', search: '', status: ''))
        .thenThrow(Exception('ارتباط با سرور برقرار نشد'));

    await cubit.load();

    expect(cubit.state.status, HiringOrdersStatus.error);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('setSearch updates searchQuery and reloads', () async {
    when(() => repository.listOrders(company: 'COMP-1', search: 'علی', status: ''))
        .thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => null);

    await cubit.setSearch('علی');

    expect(cubit.state.searchQuery, 'علی');
    verify(() => repository.listOrders(company: 'COMP-1', search: 'علی', status: ''))
        .called(1);
  });

  test('setStatusFilter updates statusFilter and reloads', () async {
    when(() => repository.listOrders(company: 'COMP-1', search: '', status: 'final'))
        .thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => null);

    await cubit.setStatusFilter('final');

    expect(cubit.state.statusFilter, 'final');
    verify(() => repository.listOrders(company: 'COMP-1', search: '', status: 'final'))
        .called(1);
  });

  test('loadPeople calls repository.people', () async {
    const person = HiringOrderPerson(
      name: 'EMP-1',
      displayName: 'حسن حسینی',
      employeeNumber: '102',
    );
    when(() => repository.people(company: 'COMP-1')).thenAnswer((_) async => [person]);

    await cubit.loadPeople();

    expect(cubit.state.people.length, 1);
    expect(cubit.state.people.first.displayName, 'حسن حسینی');
  });

  test('loadPayroll calls repository.payroll and sets currentPayroll', () async {
    const payroll = HiringOrderPayroll(currency: 'IRR', rows: [
      HiringOrderPayrollRow(
        id: 'base',
        title: 'پایه',
        period: 'monthly',
        amount: 200000000,
        state: 'available',
        message: '',
      ),
    ]);
    when(() => repository.payroll(
          company: 'COMP-1',
          employee: 'EMP-1',
          effectiveDate: '1405/01/01',
        )).thenAnswer((_) async => payroll);

    await cubit.loadPayroll(employee: 'EMP-1', effectiveDate: '1405/01/01');

    expect(cubit.state.currentPayroll, payroll);
  });
}
