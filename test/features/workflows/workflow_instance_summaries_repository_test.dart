import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

Map<String, dynamic> _summary(String name) => {
      'name': name,
      'subject': 'موضوع $name',
      'status': 'Running',
      'workflow_definition': 'WF-1',
      'current_stage': 'S-1',
      'current_stage_title': 'مرحلهٔ یک',
      'current_assignees': ['user@example.com'],
      'reference_doctype': 'ASOUD Workflow Request',
      'reference_name': 'REQ-1',
      'started_on': '2026-11-01 09:00:00',
      'completed_on': null,
    };

List<String> _names(int count) =>
    List.generate(count, (i) => 'WFI-${i + 1}');

void main() {
  late _MockClient client;
  setUp(() {
    client = _MockClient();
  });

  test('more than 100 names are sent in chunks of 100', () async {
    final calls = <List<String>>[];
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((inv) async {
      final data = inv.namedArguments[#data] as Map<String, dynamic>;
      final names = (data['names'] as List).cast<String>();
      calls.add(names);
      return names.map(_summary).toList();
    });
    final repo = FrappeWorkflowTaskRepository(client);
    final result = await repo.getInstanceSummaries(_names(150));
    expect(calls, hasLength(2));
    expect(calls[0], hasLength(100));
    expect(calls[1], hasLength(50));
    expect(result, hasLength(150));
    expect(result.map((s) => s.id), _names(150));
  });

  test('omitted names do not break the result', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((inv) async {
      final names = ((inv.namedArguments[#data] as Map)['names'] as List)
          .cast<String>();
      // The server omits the inaccessible instance WFI-2.
      return names.where((n) => n != 'WFI-2').map(_summary).toList();
    });
    final repo = FrappeWorkflowTaskRepository(client);
    final result = await repo.getInstanceSummaries(_names(3));
    expect(result.map((s) => s.id), ['WFI-1', 'WFI-3']);
  });

  test('an older server without the batch method falls back to per-instance fetches',
      () async {
    final batchCalls = <String>[];
    final singleCalls = <String>[];
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((inv) async {
      final method = inv.positionalArguments.single as String;
      if (method.endsWith('get_workflow_instance_summaries')) {
        batchCalls.add(method);
        // Frappe's raw "unknown method" answer for an older server.
        throw const ApiException(
            kind: ApiFailureKind.validation,
            statusCode: 417,
            message:
                'Failed to get method for command asoud_erp.api.v1.workflow_runtime.get_workflow_instance_summaries with module has no attribute');
      }
      if (method.endsWith('get_workflow_instance')) {
        final instance =
            (inv.namedArguments[#data] as Map)['instance'] as String;
        singleCalls.add(instance);
        return {..._summary(instance), 'can_restart': false, 'activities': []};
      }
      throw StateError('unexpected method $method');
    });
    final repo = FrappeWorkflowTaskRepository(client);
    final result = await repo.getInstanceSummaries(_names(3));
    expect(batchCalls, hasLength(1));
    expect(singleCalls, ['WFI-1', 'WFI-2', 'WFI-3']);
    expect(result.map((s) => s.id), ['WFI-1', 'WFI-2', 'WFI-3']);
  });

  test('a non-417 batch failure is not swallowed by the fallback', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => throw const ApiException(
            kind: ApiFailureKind.forbidden,
            statusCode: 403,
            message: 'اجازه انجام این عملیات را ندارید.'));
    final repo = FrappeWorkflowTaskRepository(client);
    expect(() => repo.getInstanceSummaries(_names(1)),
        throwsA(isA<ApiException>()));
  });
}
