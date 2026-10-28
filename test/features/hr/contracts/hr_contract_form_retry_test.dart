import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_issue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RetryRepository extends FakeHrContractsRepository {
  final keys = <String?>[];

  @override
  Future<HrContractRecord> saveDraftContract({required String company, required HrContractRecord draft}) async {
    keys.add(draft.clientId);
    throw Exception('قطع ارتباط');
  }
}

void main() {
  testWidgets('one form generates one nonempty client id across save retries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RetryRepository();
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: HrContractIssuePage(company: 'شرکت', repository: repository, templateRepository: FakeHrContractTemplateRepository()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('پرسنل نمونه ۱ (HR-101)').last);
    await tester.pumpAndSettle();
    final save = find.text('ذخیره پیش‌نویس');
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.scrollUntilVisible(save, 500, scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pumpAndSettle();
    }
    expect(repository.keys, hasLength(2));
    expect(repository.keys.first, matches(RegExp(r'^[0-9a-f]{48}$')));
    expect(repository.keys.last, repository.keys.first);
    expect(tester.takeException(), isNull);
  });
}
