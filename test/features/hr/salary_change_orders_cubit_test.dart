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

  test('employee change clears payroll immediately and after failure', () async {
    const payroll = SalaryChangePayrollResult(currency: 'IRR', rows: []);
    when(() => repository.payroll(company: 'COMP-1', employee: 'A',
        effectiveDate: '2026-10-28')).thenAnswer((_) async => payroll);
    await cubit.loadPayroll(employee: 'A', effectiveDate: '2026-10-28');
    expect(cubit.state.currentPayroll, same(payroll));
    final pending = Completer<SalaryChangePayrollResult>();
    when(() => repository.payroll(company: 'COMP-1', employee: 'B',
        effectiveDate: '2026-10-28')).thenAnswer((_) => pending.future);
    final load = cubit.loadPayroll(employee: 'B', effectiveDate: '2026-10-28');
    expect(cubit.state.currentPayroll, isNull);
    pending.completeError(const ApiException(kind: ApiFailureKind.network));
    await load;
    expect(cubit.state.currentPayroll, isNull);
    expect(cubit.state.errorMessage,
        'ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.');
  });

  for (final changeDate in [false, true]) {
    for (final staleFailure in [false, true]) {
      test('ignores superseded payroll date=$changeDate failure=$staleFailure', () async {
        final older = Completer<SalaryChangePayrollResult>();
        final newer = Completer<SalaryChangePayrollResult>();
        when(() => repository.payroll(company: 'COMP-1', employee: 'A',
            effectiveDate: '2026-10-28')).thenAnswer((_) => older.future);
        final employee = changeDate ? 'A' : 'B';
        final date = changeDate ? '2026-10-29' : '2026-10-28';
        when(() => repository.payroll(company: 'COMP-1', employee: employee,
            effectiveDate: date)).thenAnswer((_) => newer.future);
        final first = cubit.loadPayroll(employee: 'A', effectiveDate: '2026-10-28');
        final second = cubit.loadPayroll(employee: employee, effectiveDate: date);
        const current = SalaryChangePayrollResult(currency: 'IRR', rows: [], message: 'آخرین انتخاب');
        newer.complete(current);
        await second;
        if (staleFailure) {
          older.completeError(const ApiException(kind: ApiFailureKind.network));
        } else {
          older.complete(const SalaryChangePayrollResult(currency: 'IRR', rows: [], message: 'قدیمی'));
        }
        await first;
        expect(cubit.state.currentPayroll, same(current));
        expect(cubit.state.errorMessage, isNull);
      });
    }
  }

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
import 'dart:async';
import 'package:asoud_erp/core/network/api_exception.dart';
