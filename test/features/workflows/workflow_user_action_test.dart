import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/workflow_action_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_task_detail_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/user_action_execution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const schema = <String, dynamic>{
  'kind': 'Request',
  'sections': [
    {
      'id': 'result',
      'fields': [
        {'key': 'action_note', 'type': 'LongText', 'label': 'شرح نتیجه اقدام'}
      ]
    }
  ]
};

WorkflowTaskDetail detail({bool claim = false, bool draft = true, bool reassign = false}) =>
    WorkflowTaskDetail(
        task: WorkflowTask(
            id: 'task',
            instance: 'instance',
            stage: 'stage',
            title: 'بررسی',
            status: 'Open',
            action: claim ? 'Awaiting Claim' : ''),
        stageType: 'User Task',
        actionSchema: schema,
        actionForm: 'task',
        actionCompany: 'company',
        actionMode: 'Simple',
        requiresClaim: claim,
        allowReassign: reassign,
        allowDraft: draft);

class Client extends Fake implements FrappeApiClient {
  final calls = <Map<String, dynamic>>[];
  bool fail = false;
  Completer<void>? hold;
  @override
  bool get isAuthenticated => true;
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    calls.add({'method': method, ...?data});
    await hold?.future;
    if (fail) {
      throw const ApiException(
          kind: ApiFailureKind.validation, message: 'ثبت انجام نشد.');
    }
    return {
      'message': {
        'ok': true,
        'data': {
          'task': 'task',
          'saved': true,
          'claimed': true,
          'reassigned': true,
          'instance_status': 'Running'
        }
      }
    };
  }
}

class Tasks extends Fake implements WorkflowTaskRepository {
  Tasks(this.value);
  final WorkflowTaskDetail value;
  @override
  bool get isOfflinePreview => false;
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => value;
}

void main() {
  test('manual reassignment uses the same task API and blocks duplicate taps', () async {
    final client = Client()..hold = Completer<void>();
    final cubit = WorkflowTaskDetailCubit(Tasks(detail(reassign: true)), 'task', actionClient: client);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setValues({'action_note': 'اطلاعات واردشده'});
    final first = cubit.reassign('qualified-user');
    expect(await cubit.reassign('another-user'), isFalse);
    expect(client.calls.single['method'], endsWith('.complete_workflow_task'));
    expect(client.calls.single['action'], 'Reassign');
    expect(client.calls.single['assignee'], 'qualified-user');
    client.hold!.complete();
    expect(await first, isTrue);
    expect(cubit.state.status, WorkflowTaskDetailStatus.success);
  });

  test('disabled reassignment never calls the server', () async {
    final client = Client();
    final cubit = WorkflowTaskDetailCubit(Tasks(detail()), 'task', actionClient: client);
    addTearDown(cubit.close);
    await cubit.load();
    expect(await cubit.reassign('other'), isFalse);
    expect(client.calls, isEmpty);
  });

  test('failed reassignment preserves responsibility and current input', () async {
    final client = Client()..fail = true;
    final cubit = WorkflowTaskDetailCubit(Tasks(detail(reassign: true)), 'task', actionClient: client);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setValues({'action_note': 'اطلاعات محفوظ'});
    expect(await cubit.reassign('other'), isFalse);
    expect(cubit.state.detail, detail(reassign: true));
    expect(cubit.state.values['action_note'], 'اطلاعات محفوظ');
    expect(cubit.state.status, WorkflowTaskDetailStatus.failure);
  });
  test('failed writes preserve entered action values and do not report success',
      () async {
    final client = Client()..fail = true;
    final cubit =
        WorkflowTaskDetailCubit(Tasks(detail()), 'task', actionClient: client);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setValues(
        {'action_result': 'follow_up', 'action_note': 'در انتظار پاسخ'});
    expect(await cubit.performAction('Follow Up'), isFalse);
    expect(cubit.state.status, WorkflowTaskDetailStatus.failure);
    expect(cubit.state.values['action_note'], 'در انتظار پاسخ');
    expect(cubit.state.detail, isNotNull);
  });

  test(
      'pending action blocks a duplicate tap and draft uses the existing separate API',
      () async {
    final client = Client()..hold = Completer<void>();
    final cubit =
        WorkflowTaskDetailCubit(Tasks(detail()), 'task', actionClient: client);
    addTearDown(cubit.close);
    await cubit.load();
    final first = cubit.performAction('Claim');
    expect(await cubit.performAction('Claim'), isFalse);
    expect(client.calls, hasLength(1));
    client.hold!.complete();
    await first;
    expect(await cubit.saveDraft(), isTrue);
    expect(client.calls.last['method'], endsWith('.save_workflow_task_draft'));
    expect(client.calls.last.containsKey('action'), isFalse);
  });

  test('action drafts use the existing task API without form submission',
      () async {
    final client = Client();
    final repository =
        WorkflowActionRepository(client, 'company', 'task', uploads: false);
    await repository.draft({'action_note': 'نیمه‌تمام'});
    expect(client.calls.single['task'], 'task');
    expect(client.calls.single['response'], {'action_note': 'نیمه‌تمام'});
    expect(
        client.calls.single['method'], endsWith('.save_workflow_task_draft'));
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'shared action presents only claim before editable result at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final task = detail(claim: true);
      final cubit =
          WorkflowTaskDetailCubit(Tasks(task), 'task', actionClient: Client());
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        RepositoryProvider<FrappeApiClient>.value(
          value: Client(),
          child: BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: AsoudTheme.light,
              builder: (_, child) => Directionality(
                  textDirection: TextDirection.rtl, child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: UserActionExecution(detail: task))),
            ),
          ),
        ),
      );
      expect(find.text('دریافت اقدام'), findsOneWidget);
      expect(find.text('ثبت و تکمیل وظیفه'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
