import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_print_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  testWidgets('print banner uses server payload instead of record status', (tester) async {
    final client = _Client();
    const method = 'asoud_erp.api.v1.employment_contracts.get_contract_print';
    when(() => client.callAsoudMethod(method, data: {'contract_id': 'CONT-00001'}))
        .thenAnswer((_) async => {
          'is_draft': true,
          'draft_banner': '«پیش‌نویس ـ فاقد اعتبار نهایی»',
          'contract_number': 'شماره پس از صدور',
          'html': '<html dir="rtl"><body>«پیش‌نویس ـ فاقد اعتبار نهایی»</body></html>',
        });
    final repository = ServerHrContractsRepository(client);
    final record = (await FakeHrContractsRepository().listContracts(company: 'شرکت')).first;
    expect(record.isFinal, isTrue);
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: HrContractPrintPage(
        contract: record,
        loadPayload: () => repository.getPrintPayload(company: 'شرکت', id: 'CONT-00001'),
      ),
    ));
    await tester.pump();
    expect(find.text('«پیش‌نویس ـ فاقد اعتبار نهایی»'), findsOneWidget);
    verify(() => client.callAsoudMethod(method, data: {'contract_id': 'CONT-00001'})).called(1);
    await tester.pumpWidget(const SizedBox());
  });
}
