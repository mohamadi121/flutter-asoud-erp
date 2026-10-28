import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_issue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Staff extends FakeHrContractsRepository {
  bool fail = false;
  @override
  Future<List<EmployeeOption>> getStaffList({required String company}) async {
    if (fail) throw const ApiException(kind: ApiFailureKind.network, message: 'شبکه');
    return super.getStaffList(company: company);
  }
}

class _Templates extends FakeHrContractTemplateRepository {
  bool fail = false;
  @override
  Future<HrContractTemplate> getTemplate({required String company, String? id}) async {
    if (fail) throw const ApiException(kind: ApiFailureKind.network, message: 'شبکه');
    return super.getTemplate(company: company, id: id);
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final templateFailure in [true, false]) {
      testWidgets('initial load failure and retry at $width; template=$templateFailure',
          (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(Size(width, 844));
        final staff = _Staff()..fail = !templateFailure;
        final templates = _Templates()..fail = templateFailure;
        await tester.pumpWidget(MaterialApp(
          builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: HrContractIssuePage(company: 'شرکت آزمون', repository: staff,
              templateRepository: templates),
        ));
        await tester.pumpAndSettle();
        expect(find.text('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'), findsOneWidget);
        expect(find.byType(Form), findsNothing);
        expect(tester.takeException(), isNull);
        staff.fail = false;
        templates.fail = false;
        await tester.tap(find.text('تلاش دوباره'));
        await tester.pumpAndSettle();
        expect(find.byType(Form), findsOneWidget);
        expect(find.text('تلاش دوباره'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
