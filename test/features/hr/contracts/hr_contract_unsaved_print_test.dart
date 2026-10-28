import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_print_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('unsaved contract explains the print prerequisite at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final contract = (await FakeHrContractsRepository().listContracts(company: 'شرکت')).first;
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HrContractPrintPage(contract: contract),
      ));
      await tester.pumpAndSettle();
      final button = find.text('چاپ یا ذخیره PDF');
      await tester.scrollUntilVisible(button, 300);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('برای چاپ، ابتدا سند پرسنلی را ذخیره و خروجی چاپ سرور را دریافت کنید.'), findsOneWidget);
      expect(find.text('ارسال به چاپگر...'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
