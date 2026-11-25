import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  late _MockClient client;
  late List<String> sentRequestIds;
  late int calls;

  setUp(() {
    client = _MockClient();
    sentRequestIds = <String>[];
    calls = 0;
  });

  /// The real `complete_workflow_task` answer is `success({task, instance_status})`;
  /// `callAsoudMethod` unwraps the envelope and returns that `data` map.
  Map<String, dynamic> completeAnswer(String task) =>
      {'task': task, 'instance_status': 'Running'};

  void stubComplete() {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      calls++;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      final task = data['task'] as String;
      sentRequestIds.add(data['request_id'] as String);
      // The first completion fails with a network error (outcome unknown).
      if (calls == 1) {
        throw const ApiException(
            kind: ApiFailureKind.network, message: 'offline');
      }
      return completeAnswer(task);
    });
  }

  test('a network-failed completion is retried with the same request_id',
      () async {
    stubComplete();
    final repo = FrappeWorkflowTaskRepository(client);

    await expectLater(
        repo.completeTask(task: 'T-1', action: 'Approve'),
        throwsA(isA<ApiException>()));
    // The same decision, retried after the network failure, reuses the id.
    await repo.completeTask(task: 'T-1', action: 'Approve');

    expect(sentRequestIds, hasLength(2));
    expect(sentRequestIds[0], isNotEmpty);
    expect(sentRequestIds[0], sentRequestIds[1]);
  });

  test('a different task gets a fresh request_id', () async {
    stubComplete();
    final repo = FrappeWorkflowTaskRepository(client);

    await expectLater(
        repo.completeTask(task: 'T-1', action: 'Approve'),
        throwsA(isA<ApiException>()));
    await repo.completeTask(task: 'T-1', action: 'Approve');
    // A new decision on another task must not reuse the previous id.
    await repo.completeTask(task: 'T-2', action: 'Approve');

    expect(sentRequestIds, hasLength(3));
    expect(sentRequestIds[0], sentRequestIds[1]);
    expect(sentRequestIds[2], isNot(sentRequestIds[0]));
  });

  test('a definitive server answer clears the id so the next attempt is fresh',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      calls++;
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      sentRequestIds.add(data['request_id'] as String);
      // First call: a validation error (definitive — the decision did not go
      // through). Second call: success.
      if (calls == 1) {
        throw const ApiException(
            kind: ApiFailureKind.validation, message: 'رد مجاز نیست',
            statusCode: 417);
      }
      return completeAnswer(data['task'] as String);
    });
    final repo = FrappeWorkflowTaskRepository(client);

    await expectLater(
        repo.completeTask(task: 'T-1', action: 'Reject'),
        throwsA(isA<ApiException>()));
    await repo.completeTask(task: 'T-1', action: 'Reject');

    expect(sentRequestIds, hasLength(2));
    // A definitive answer means the next attempt starts with a fresh id.
    expect(sentRequestIds[1], isNot(sentRequestIds[0]));
  });
}
