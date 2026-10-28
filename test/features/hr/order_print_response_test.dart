import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/data/salary_change_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/hiring_orders_cubit.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/salary_change_orders_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Hiring extends Mock implements HiringOrderRepository {}
class _Salary extends Mock implements SalaryChangeOrderRepository {}

void main() {
  test('hiring template publish blocks double taps and resets after failure', () async {
    final repository = _Hiring();
    final cubit = HiringOrdersCubit(repository: repository, company: 'شرکت');
    addTearDown(cubit.close);
    final pending = Completer<Map<String, dynamic>>();
    when(() => repository.saveTemplate(company: 'شرکت', revision: 0, template: any(named: 'template')))
        .thenAnswer((_) => pending.future);
    final first = cubit.publishTemplate({});
    expect(await cubit.publishTemplate({}), isFalse);
    verify(() => repository.saveTemplate(company: 'شرکت', revision: 0, template: any(named: 'template'))).called(1);
    pending.completeError(const ApiException(kind: ApiFailureKind.timeout, message: 'مهلت پایان یافت'));
    expect(await first, isFalse);
    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.errorMessage, 'پاسخ سرور طول کشید. دوباره تلاش کنید.');
  });
  test('salary template publish blocks double taps and resets after failure', () async {
    final repository = _Salary();
    final cubit = SalaryChangeOrdersCubit(repository: repository, company: 'شرکت');
    addTearDown(cubit.close);
    final pending = Completer<Map<String, dynamic>>();
    when(() => repository.saveTemplate(company: 'شرکت', revision: 0, template: any(named: 'template')))
        .thenAnswer((_) => pending.future);
    final first = cubit.publishTemplate({});
    expect(await cubit.publishTemplate({}), isFalse);
    verify(() => repository.saveTemplate(company: 'شرکت', revision: 0, template: any(named: 'template'))).called(1);
    pending.completeError(const ApiException(kind: ApiFailureKind.timeout, message: 'مهلت پایان یافت'));
    expect(await first, isFalse);
    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.errorMessage, 'پاسخ سرور طول کشید. دوباره تلاش کنید.');
  });
  for (final staleFailure in [false, true]) {
    test('hiring ignores superseded print failure=$staleFailure', () async {
      final repository = _Hiring();
      final cubit = HiringOrdersCubit(repository: repository, company: 'شرکت');
      addTearDown(cubit.close);
      final older = Completer<HiringOrderPrint>();
      when(() => repository.printOrder(name: 'A')).thenAnswer((_) => older.future);
      const current = HiringOrderPrint(html: '<p>جدید</p>', status: 'final', number: '۲', draftBanner: false);
      when(() => repository.printOrder(name: 'B')).thenAnswer((_) async => current);
      final first = cubit.loadPrint('A');
      await cubit.loadPrint('B');
      if (staleFailure) {
        older.completeError(TimeoutException(''));
      } else {
        older.complete(const HiringOrderPrint(html: '<p>قدیمی</p>', status: 'draft', number: '۱', draftBanner: true));
      }
      await first;
      expect(cubit.state.currentPrint, same(current));
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });
    test('salary ignores superseded print failure=$staleFailure', () async {
      final repository = _Salary();
      final cubit = SalaryChangeOrdersCubit(repository: repository, company: 'شرکت');
      addTearDown(cubit.close);
      final older = Completer<SalaryChangeOrderPrint>();
      when(() => repository.printOrder(name: 'A')).thenAnswer((_) => older.future);
      const current = SalaryChangeOrderPrint(html: '<p>جدید</p>', status: 'final', number: '۲', draftBanner: false);
      when(() => repository.printOrder(name: 'B')).thenAnswer((_) async => current);
      final first = cubit.loadPrint('A');
      await cubit.loadPrint('B');
      if (staleFailure) {
        older.completeError(TimeoutException(''));
      } else {
        older.complete(const SalaryChangeOrderPrint(html: '<p>قدیمی</p>', status: 'draft', number: '۱', draftBanner: true));
      }
      await first;
      expect(cubit.state.currentPrint, same(current));
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });
  }
}
