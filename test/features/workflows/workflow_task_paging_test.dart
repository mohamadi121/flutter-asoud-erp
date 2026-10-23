import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClient extends Mock implements FrappeClient {}

Map<String, dynamic> _row(String name) => {
      'name': name,
      'workflow_instance': 'WFI-1',
      'workflow_stage': 'S-1',
      'task_title': 'بررسی',
      'status': 'Open',
    };

void main() {
  late _MockClient client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _MockClient();
  });

  test('old server list response is accepted and marked partial', () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => [_row('T-1'), _row('T-2')]);
    final repo = FrappeWorkflowTaskRepository(client);
    final tasks = await repo.getMyTasks();
    expect(tasks.map((t) => t.id), ['T-1', 'T-2']);
    expect(repo.listsAreComplete, isFalse);
  });

  test('paged response is followed to the end and the preview wrapper forwards completeness',
      () async {
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((inv) async {
      final data = inv.namedArguments[#data] as Map<String, dynamic>;
      return data['start'] == '0'
          ? {'items': [_row('T-1')], 'next_cursor': '1'}
          : {'items': [_row('T-2')], 'next_cursor': null};
    });
    final remote = FrappeWorkflowTaskRepository(client);
    final preview = PreviewWorkflowTaskRepository(remote);
    final WorkflowTaskRepository asInterface = preview;
    expect(asInterface, isA<CompleteWorkflowLists>());
    final tasks = await preview.getMyTasks();
    expect(tasks.map((t) => t.id), ['T-1', 'T-2']);
    expect(preview.listsAreComplete, isTrue);
  });
}
