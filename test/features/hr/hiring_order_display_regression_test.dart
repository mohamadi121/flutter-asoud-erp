import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hiring_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements HiringOrderRepository {}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('hiring dates are Jalali and missing total is not zero at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      final iso = DateTime.now().toIso8601String().split('T').first;
      when(() => repository.listOrders(company: 'شرکت', search: '', status: ''))
          .thenAnswer((_) async => [HiringOrderSummary(name: 'A', number: '۱۲',
            employee: 'A', employeeName: 'علی رضایی', status: 'draft', statusLabel: 'پیش‌نویس',
            effectiveDate: iso, issueDate: '', draftedOn: iso, revision: 1)]);
      when(() => repository.getTemplate(company: 'شرکت')).thenAnswer((_) async => null);
      when(() => repository.people(company: 'شرکت')).thenAnswer((_) async => [
        const HiringOrderPerson(name: 'A', displayName: 'علی رضایی', employeeNumber: '۱۲'),
      ]);
      when(() => repository.payroll(company: 'شرکت', employee: 'A', effectiveDate: any(named: 'effectiveDate')))
          .thenAnswer((_) async => const HiringOrderPayroll(currency: 'IRR', rows: [
            HiringOrderPayrollRow(id: 'base', title: 'حقوق پایه', period: 'monthly',
              amount: 12, state: 'available', message: ''),
          ]));
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HiringOrdersPage(company: 'شرکت', repository: repository, capabilities: Capabilities.full),
      ));
      await tester.pumpAndSettle();
      expect(find.text('تاریخ اجرا: ${formatJalaliIso(iso)}'), findsOneWidget);
      await tester.tap(find.text('＋ حکم جدید'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('علی رضایی — ۱۲').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('اطلاعات موجود نیست'), 250);
      expect(find.text('اطلاعات موجود نیست'), findsWidgets);
      expect(find.text('۰ ریال'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
