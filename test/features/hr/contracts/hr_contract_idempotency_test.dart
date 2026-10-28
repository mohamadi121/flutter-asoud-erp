import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  test('draft retry reuses client id and finalize sends the same key', () async {
    final client = _Client();
    final repository = ServerHrContractsRepository(client);
    final draft = (await FakeHrContractsRepository().listContracts(company: 'شرکت')).first
        .copyWith(id: '', clientId: 'form-retry-1');
    final requests = <Map<String, dynamic>>[];
    var attempts = 0;
    when(() => client.callAsoudMethod(any(), data: any(named: 'data'))).thenAnswer((invocation) async {
      final method = invocation.positionalArguments.single as String;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      requests.add(data);
      if (method.endsWith('save_contract_draft')) {
        if (attempts++ == 0) throw Exception('قطع ارتباط');
        return {'contract_id': 'CONT-00001', 'status': 'پیش‌نویس'};
      }
      return {'contract_id': 'CONT-00001', 'status': 'نهایی'};
    });
    await expectLater(repository.submitContract(company: 'شرکت', draft: draft), throwsException);
    await repository.submitContract(company: 'شرکت', draft: draft);
    expect(requests.take(3).map((data) => data['client_id']), everyElement('form-retry-1'));
    expect(requests[2]['contract_id'], 'CONT-00001');
  });
}
