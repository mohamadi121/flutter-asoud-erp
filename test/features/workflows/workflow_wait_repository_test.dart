import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/workflow_wait_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeClient {}

void main() {
  late _Client client;
  late WorkflowWaitRepository repository;
  var user = 'first@example.test', server = 'https://first.example.test';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    user = 'first@example.test'; server = 'https://first.example.test';
    client = _Client(); repository = WorkflowWaitRepository(client);
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenAnswer((_) => server);
    when(() => client.getCurrentUser()).thenAnswer((_) async => FrappeUserContext(
        userId: user, fullName: 'کاربر مجاز', roles: const ['System Manager']));
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenAnswer((_) async => {
      'message': {'ok': true, 'data': {'wait_version': 1}}});
  });

  test('server save requires a positive envelope and does not enter the offline mutation queue', () async {
    await repository.save('wf', 'wait', {'wait_version': 1});
    verify(() => client.callMethod('asoud_erp.api.v1.workflow_wait.save_wait_settings', data: {
      'definition': 'wf', 'stage': 'wait', 'config': {'wait_version': 1}})).called(1);
    verifyNever(() => client.callAsoudMethod(any(), data: any(named: 'data')));
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenAnswer((_) async => {
      'message': {'ok': false, 'data': {}}});
    await expectLater(repository.save('wf', 'wait', {}), throwsStateError);
  });

  test('a network error is not reported as successful server save', () async {
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenThrow(const ApiException(
        kind: ApiFailureKind.network, message: 'ارتباط برقرار نشد'));
    await expectLater(repository.save('wf', 'wait', {}), throwsA(isA<ApiException>()));
    verifyNever(() => client.callAsoudMethod(any(), data: any(named: 'data')));
  });

  test('drafts are isolated by server, user, workflow and stage; clear only removes the current draft', () async {
    await repository.saveDraft('wf', 'wait', {'wait_value': 'bad but retained'});
    expect(await repository.draft('wf', 'wait'), {'wait_value': 'bad but retained'});
    user = 'second@example.test';
    expect(await repository.draft('wf', 'wait'), isNull);
    user = 'first@example.test'; server = 'https://other.example.test';
    expect(await repository.draft('wf', 'wait'), isNull);
    server = 'https://first.example.test';
    expect(await repository.draft('wf', 'other-stage'), isNull);
    await repository.saveDraft('other-workflow', 'wait', {'title': 'باقی می‌ماند'});
    await repository.clearDraft('wf', 'wait');
    expect(await repository.draft('wf', 'wait'), isNull);
    expect(await repository.draft('other-workflow', 'wait'), {'title': 'باقی می‌ماند'});
    verifyNever(() => client.callMethod(any(), data: any(named: 'data')));
  });
}
