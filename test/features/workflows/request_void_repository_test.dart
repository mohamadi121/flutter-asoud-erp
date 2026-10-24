import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/request_void_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  test('void and reissue call the HR Manager endpoints with the documented arguments',
      () async {
    final client = _MockClient();
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {'name': 'REQ-1'});
    final repository = RequestVoidRepository(client);
    expect(await repository.voidDocument('REQ-1', 'اشتباه'), {'name': 'REQ-1'});
    await repository.reissue('REQ-1');
    verify(() => client.callAsoudMethod(
            'asoud_erp.api.v1.workflow_request.void_native_document',
            data: {'name': 'REQ-1', 'reason': 'اشتباه'}))
        .called(1);
    verify(() => client.callAsoudMethod(
            'asoud_erp.api.v1.workflow_request.reissue_native_document',
            data: {'name': 'REQ-1'}))
        .called(1);
  });
}
