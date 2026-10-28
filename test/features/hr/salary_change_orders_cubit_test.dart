import 'package:asoud_erp/features/hr/data/salary_change_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/salary_change_orders_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements SalaryChangeOrderRepository {}

void main() {
  late _Repository repository;
  late SalaryChangeOrdersCubit cubit;

  setUp(() {
    repository = _Repository();
    cubit = SalaryChangeOrdersCubit(repository: repository, company: 'COMP-1');
  });

  tearDown(() => cubit.close());

  test('initial state has correct defaults', () {
    expect(cubit.state.status, SalaryChangeOrdersStatus.initial);
    expect(cubit.state.orders, isEmpty);
    expect(cubit.state.statusFilter, 'all');
    expect(cubit.state.applicationStatusFilter, 'all');
  });

  test('load() emits loaded state on success', () async {
    const summary = SalaryChangeOrderSummary(
      name: 'ENTRY-1',
      number: 'SAL-1405-001',
      employee: 'EMP-1',
      employeeName: 'علی رضایی',
      status: 'draft',
      statusLabel: 'پیش‌نویس',
      applicationStatus: 'not_applied',
      applicationStatusLabel: 'اعمال‌نشده',
      effectiveDate: '1405/01/01',
      issueDate: '',
      draftedOn: '1405/01/01',
      reason: 'annual',
      reasonLabel: 'افزایش سالانه',
      revision: 1,
    );
    when(() => repository.listOrders(
          company: 'COMP-1',
          search: '',
          status: '',
          applicationStatus: '',
        )).thenAnswer((_) async => [summary]);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => {'revision': 1});

    await cubit.load();

    expect(cubit.state.status, SalaryChangeOrdersStatus.loaded);
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.employeeName, 'علی رضایی');
    expect(cubit.state.publishedTemplate?['revision'], 1);
  });

  test('load() emits error state on failure', () async {
    when(() => repository.listOrders(
          company: 'COMP-1',
          search: '',
          status: '',
          applicationStatus: '',
        )).thenThrow(Exception('خطای شبکه'));

    await cubit.load();

    expect(cubit.state.status, SalaryChangeOrdersStatus.error);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('setSearch and filter updates trigger reload', () async {
    when(() => repository.listOrders(
          company: 'COMP-1',
          search: 'علی',
          status: '',
          applicationStatus: '',
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => null);

    await cubit.setSearch('علی');
    expect(cubit.state.searchQuery, 'علی');

    when(() => repository.listOrders(
          company: 'COMP-1',
          search: 'علی',
          status: 'final',
          applicationStatus: '',
        )).thenAnswer((_) async => []);

    await cubit.setStatusFilter('final');
    expect(cubit.state.statusFilter, 'final');

    when(() => repository.listOrders(
          company: 'COMP-1',
          search: 'علی',
          status: 'final',
          applicationStatus: 'applied',
        )).thenAnswer((_) async => []);

    await cubit.setApplicationStatusFilter('applied');
    expect(cubit.state.applicationStatusFilter, 'applied');
  });

  test('approveOrder and applyToPayroll succeed', () async {
    const detail = SalaryChangeOrderDetail(
      name: 'ENTRY-1',
      number: 'SAL-1405-001',
      company: 'COMP-1',
      companyName: 'تابان',
      employee: 'EMP-1',
      employeeName: 'علی رضایی',
      employeeNumber: '101',
      status: 'final',
      statusLabel: 'نهایی',
      applicationStatus: 'applied',
      applicationStatusLabel: 'اعمال‌شده',
      effectiveDate: '1405/01/01',
      issueDate: '1405/01/05',
      draftedOn: '1405/01/01',
      reason: 'annual',
      reasonLabel: 'افزایش سالانه',
      revision: 3,
    );

    when(() => repository.approveOrder(
          name: 'ENTRY-1',
          revision: 2,
          requestId: 'app-1',
        )).thenAnswer((_) async => detail);
    when(() => repository.listOrders(
          company: 'COMP-1',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'COMP-1'))
        .thenAnswer((_) async => null);

    final ok = await cubit.approveOrder(
      name: 'ENTRY-1',
      revision: 2,
      requestId: 'app-1',
    );
    expect(ok, isTrue);
    expect(cubit.state.currentOrder?.isFinal, isTrue);

    when(() => repository.applyToPayroll(
          name: 'ENTRY-1',
          operationId: 'op-1',
        )).thenAnswer((_) async => detail);

    final applied = await cubit.applyToPayroll(
      name: 'ENTRY-1',
      operationId: 'op-1',
    );
    expect(applied, isTrue);
    expect(cubit.state.currentOrder?.isApplied, isTrue);
  });
}
