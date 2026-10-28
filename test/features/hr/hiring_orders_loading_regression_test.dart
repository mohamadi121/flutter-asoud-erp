import 'dart:async';

import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/hiring_orders_cubit.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hiring_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements HiringOrderRepository {}

void main() {
  test('late payroll failure cannot clear the latest employee snapshot', () async {
    final repository = _Repository();
    final cubit = HiringOrdersCubit(repository: repository, company: 'شرکت');
    addTearDown(cubit.close);
    final older = Completer<HiringOrderPayroll>();
    when(() => repository.payroll(company: 'شرکت', employee: 'A', effectiveDate: '2026-10-28'))
        .thenAnswer((_) => older.future);
    const payroll = HiringOrderPayroll(currency: 'IRR', rows: []);
    when(() => repository.payroll(company: 'شرکت', employee: 'B', effectiveDate: '2026-10-28'))
        .thenAnswer((_) async => payroll);
    final first = cubit.loadPayroll(employee: 'A', effectiveDate: '2026-10-28');
    await cubit.loadPayroll(employee: 'B', effectiveDate: '2026-10-28');
    older.completeError(TimeoutException(''));
    await first;
    expect(cubit.state.currentPayroll, same(payroll));
    expect(cubit.state.errorMessage, isNull);
  });

  test('late search failure cannot replace the latest loaded list', () async {
    final repository = _Repository();
    final cubit = HiringOrdersCubit(repository: repository, company: 'شرکت');
    addTearDown(cubit.close);
    final older = Completer<List<HiringOrderSummary>>();
    when(() => repository.listOrders(company: 'شرکت', search: '', status: ''))
        .thenAnswer((_) => older.future);
    when(() => repository.listOrders(company: 'شرکت', search: 'جدید', status: ''))
        .thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت')).thenAnswer((_) async => null);
    final first = cubit.load();
    await cubit.setSearch('جدید');
    older.completeError(TimeoutException(''));
    await first;
    expect(cubit.state.searchQuery, 'جدید');
    expect(cubit.state.status, HiringOrdersStatus.loaded);
    expect(cubit.state.errorMessage, isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('people failure is visible and retryable at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      when(() => repository.listOrders(company: 'شرکت', search: '', status: ''))
          .thenAnswer((_) async => []);
      when(() => repository.getTemplate(company: 'شرکت')).thenAnswer((_) async => null);
      var calls = 0;
      when(() => repository.people(company: 'شرکت')).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw TimeoutException('');
        return [];
      });
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HiringOrdersPage(company: 'شرکت', repository: repository, capabilities: Capabilities.full),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('＋ حکم جدید'));
      await tester.pumpAndSettle();
      expect(find.textContaining('دریافت فهرست پرسنل انجام نشد.'), findsOneWidget);
      final retry = find.text('دریافت دوباره پرسنل');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('دریافت فهرست پرسنل انجام نشد.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
