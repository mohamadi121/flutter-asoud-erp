import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contracts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends FakeHrContractsRepository {
  int calls = 0;

  @override
  Future<List<HrContractRecord>> listContracts({required String company,
      String? query, String? statusFilter, int page = 1, int pageSize = 20}) async {
    calls++;
    if (calls == 1) {
      throw const ApiException(kind: ApiFailureKind.server, message: 'خطا');
    }
    return [];
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('contract list displays failure reason and retries at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HrContractsPage(company: 'شرکت', repository: repository),
      ));
      await tester.pumpAndSettle();
      final reason = find.text('خطایی در سرور رخ داد. کمی بعد دوباره تلاش کنید.');
      await tester.scrollUntilVisible(reason, 150);
      expect(reason, findsOneWidget);
      final retry = find.text('تلاش دوباره');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(reason, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
