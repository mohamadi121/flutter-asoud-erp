import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/data/salary_change_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/hiring_orders_cubit.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/salary_change_orders_cubit.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hiring_orders_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/salary_change_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Hiring extends Mock implements HiringOrderRepository {}
class _Salary extends Mock implements SalaryChangeOrderRepository {}

void main() {
  for (final hiring in [true, false]) {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('template failure preserves list and retries; hiring=$hiring width=$width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const failure = ApiException(kind: ApiFailureKind.server, message: 'خطا');
        final h = _Hiring();
        final s = _Salary();
        if (hiring) {
          when(() => h.listOrders(company: 'شرکت', search: '', status: '')).thenAnswer((_) async => []);
          when(() => h.people(company: 'شرکت')).thenAnswer((_) async => []);
          when(() => h.getTemplate(company: 'شرکت')).thenThrow(failure);
          final cubit = HiringOrdersCubit(repository: h, company: 'شرکت');
          await cubit.load();
          expect(cubit.state.status, HiringOrdersStatus.loaded);
          expect(cubit.state.templateError, 'خطایی در سرور رخ داد. کمی بعد دوباره تلاش کنید.');
          await cubit.close();
        } else {
          when(() => s.listOrders(company: 'شرکت', search: '', status: '', applicationStatus: '')).thenAnswer((_) async => []);
          when(() => s.people(company: 'شرکت')).thenAnswer((_) async => []);
          when(() => s.getTemplate(company: 'شرکت')).thenThrow(failure);
          final cubit = SalaryChangeOrdersCubit(repository: s, company: 'شرکت');
          await cubit.load();
          expect(cubit.state.status, SalaryChangeOrdersStatus.loaded);
          expect(cubit.state.templateError, 'خطایی در سرور رخ داد. کمی بعد دوباره تلاش کنید.');
          await cubit.close();
        }
        await tester.pumpWidget(MaterialApp(
          builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: hiring ? HiringOrdersPage(company: 'شرکت', repository: h, capabilities: Capabilities.full)
              : SalaryChangeOrdersPage(company: 'شرکت', repository: s),
        ));
        await tester.pumpAndSettle();
        expect(find.textContaining('دریافت قالب انجام نشد.'), findsOneWidget);
        if (hiring) {
          when(() => h.getTemplate(company: 'شرکت')).thenAnswer((_) async => null);
        } else {
          when(() => s.getTemplate(company: 'شرکت')).thenAnswer((_) async => null);
        }
        await tester.tap(find.text('دریافت دوباره قالب'));
        await tester.pumpAndSettle();
        expect(find.textContaining('دریافت قالب انجام نشد.'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
