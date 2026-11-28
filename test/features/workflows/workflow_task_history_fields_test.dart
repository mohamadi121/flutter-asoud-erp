import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

class _Repo implements WorkflowTaskRepository {
  _Repo({required this.detail});
  final WorkflowTaskDetail detail;

  @override
  bool get isOfflinePreview => false;

  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      [detail.task];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) async {}

  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) async =>
      '';

  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) async {}
}

Widget _wrap(Widget child, WorkflowTaskRepository repository) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, c) =>
            Directionality(textDirection: TextDirection.rtl, child: c!),
        home: child,
      ),
    );

WorkflowTask _task() => const WorkflowTask(
      id: 'WFT-2026-00042',
      instance: 'WFI-2026-00042',
      stage: 'STAGE-APPROVAL',
      title: 'تأیید درخواست خرید لپ‌تاپ',
      status: 'Open',
    );

/// The exact `get_workflow_task` answer the deployed backend returns: the
/// additive `actor_name`/`before`/`after`/`labels` on each history row and the
/// additive `fieldtype` on each document value.
Map<String, dynamic> _taskAnswer({
  List<Map<String, dynamic>> history = const [],
  List<Map<String, dynamic>> documentValues = const [],
}) =>
    {
      'name': 'WFT-2026-00042',
      'workflow_instance': 'WFI-2026-00042',
      'workflow_stage': 'STAGE-APPROVAL',
      'task_title': 'تأیید درخواست خرید لپ‌تاپ',
      'status': 'Open',
      'stage_type': 'Approval',
      'config': {'activity_type': '', 'form_fields': []},
      'history': history,
      'previous_data': [],
      'document': {'doctype': 'Asset Movement', 'name': 'AM-1', 'values': documentValues},
    };

Future<WorkflowTaskDetail> _getTask(
        _MockClient client, Map<String, dynamic> answer) async {
  when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
      .thenAnswer((_) async => answer);
  return FrappeWorkflowTaskRepository(client).getTask('WFT-2026-00042');
}

void main() {
  group('history row parsing (get_workflow_task)', () {
    test('new server: actor_name and change lines are parsed', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(history: [
        {
          'actor': 'ali@example.com',
          'action': 'Edited',
          'comment': '',
          'created_on': '2026-10-01 08:30:00',
          'actor_name': 'علی رضایی',
          'before': {'amount': 100},
          'after': {'amount': 250},
          'labels': {'amount': 'مبلغ'},
        },
      ]));

      final activity = detail.activities.single;
      expect(activity.actorName, 'علی رضایی');
      expect(activity.actor, 'ali@example.com');
      expect(activity.before, {'amount': 100});
      expect(activity.after, {'amount': 250});
      expect(activity.labels, {'amount': 'مبلغ'});
    });

    test('older server: missing keys fall back to the raw actor and no change lines', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(history: [
        {
          'actor': 'ali@example.com',
          'action': 'Approve',
          'comment': '',
          'created_on': '2026-10-01 08:30:00',
        },
      ]));

      final activity = detail.activities.single;
      expect(activity.actorName, isEmpty);
      expect(activity.actor, 'ali@example.com');
      expect(activity.before, isEmpty);
      expect(activity.after, isEmpty);
      expect(activity.labels, isEmpty);
    });

    test('malformed before/after/labels (wrong types) are treated as empty, not a crash', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(history: [
        {
          'actor': 'ali@example.com',
          'action': 'Edited',
          'comment': '',
          'created_on': '2026-10-01 08:30:00',
          'actor_name': 'علی رضایی',
          'before': 'not-a-map',
          'after': [1, 2, 3],
          'labels': 42,
        },
      ]));

      final activity = detail.activities.single;
      expect(activity.actorName, 'علی رضایی');
      expect(activity.before, isEmpty);
      expect(activity.after, isEmpty);
      expect(activity.labels, isEmpty);
    });

    test('null actor_name and null created_on are tolerated', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(history: [
        {
          'actor': 'ali@example.com',
          'action': 'Approve',
          'comment': null,
          'created_on': null,
          'actor_name': null,
        },
      ]));

      final activity = detail.activities.single;
      expect(activity.actorName, isEmpty);
      expect(activity.comment, isEmpty);
      expect(activity.createdOn, isNull);
    });
  });

  group('document value fieldtype parsing', () {
    test('Attach fieldtype is kept on the document value', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(documentValues: [
        {
          'key': 'attachment',
          'label': 'پیوست',
          'value': '/private/files/report.pdf?token=abc',
          'read_only': true,
          'fieldtype': 'Attach',
        },
      ]));

      final value = detail.documentValues.single;
      expect(value.fieldtype, 'Attach');
      expect(value.value, '/private/files/report.pdf?token=abc');
    });

    test('a value without fieldtype (older server) keeps fieldtype null', () async {
      final client = _MockClient();
      final detail = await _getTask(client, _taskAnswer(documentValues: [
        {
          'key': 'asset',
          'label': 'تجهیز',
          'value': 'لپ‌تاپ اداری',
          'read_only': true,
        },
      ]));

      expect(detail.documentValues.single.fieldtype, isNull);
    });
  });

  group('history row rendering', () {
    testWidgets('new server: actor name and change line are shown, not the raw email',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = WorkflowTaskDetail(
        task: _task(),
        stageType: 'Approval',
        activities: [
          WorkflowTaskActivity(
            actor: 'ali@example.com',
            action: 'Edited',
            actorName: 'علی رضایی',
            before: {'amount': 100},
            after: {'amount': 250},
            labels: {'amount': 'مبلغ'},
            createdOn: DateTime.utc(2026, 10, 1, 8, 30),
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
          const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
          _Repo(detail: detail)));
      await tester.pumpAndSettle();

      // The full name replaces the raw email address (it sits in the meta line
      // joined with the Jalali date).
      expect(find.textContaining('علی رضایی'), findsOneWidget);
      expect(find.textContaining('ali@example.com'), findsNothing);
      // The change line «مبلغ: 100 ← 250» is rendered (the timeline reuses
      // requestActivityComment, which shows the stored values verbatim).
      expect(find.textContaining('مبلغ: 100 ← 250'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('older server: raw actor shown, no change line, at 320 px',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = WorkflowTaskDetail(
        task: _task(),
        stageType: 'Approval',
        activities: [
          WorkflowTaskActivity(
            actor: 'ali@example.com',
            action: 'Approve',
            createdOn: DateTime.utc(2026, 10, 1, 8, 30),
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
          const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
          _Repo(detail: detail)));
      await tester.pumpAndSettle();

      // No actor_name: the raw actor (email) is shown, wrapped for RTL.
      expect(find.textContaining('ali@example.com'), findsOneWidget);
      // No change lines: the «مبلغ» label never appears.
      expect(find.textContaining('مبلغ'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('attach document value rendering', () {
    /// Opens the «جزئیات فنی» expansion tile so the document values are built.
    Future<void> openTechnical(WidgetTester tester) async {
      await tester.tap(find.text('جزئیات فنی'));
      await tester.pumpAndSettle();
    }

    testWidgets('Attach value shows the file name, not the raw path',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = WorkflowTaskDetail(
        task: _task(),
        stageType: 'Approval',
        documentValues: [
          WorkflowTaskDataValue(
            key: 'attachment',
            label: 'پیوست',
            value: '/private/files/report.pdf?token=abc',
            fieldtype: 'Attach',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
          const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
          _Repo(detail: detail)));
      await tester.pumpAndSettle();
      await openTechnical(tester);

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.textContaining('/private/files'), findsNothing);
      expect(find.textContaining('token=abc'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Attach Image value shows the file name too', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = WorkflowTaskDetail(
        task: _task(),
        stageType: 'Approval',
        documentValues: [
          WorkflowTaskDataValue(
            key: 'photo',
            label: 'تصویر',
            value: '/private/files/photo.jpg',
            fieldtype: 'Attach Image',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
          const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
          _Repo(detail: detail)));
      await tester.pumpAndSettle();
      await openTechnical(tester);

      expect(find.text('photo.jpg'), findsOneWidget);
      expect(find.textContaining('/private/files'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-Attach fieldtype keeps the raw value', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = WorkflowTaskDetail(
        task: _task(),
        stageType: 'Approval',
        documentValues: [
          WorkflowTaskDataValue(
            key: 'asset',
            label: 'تجهیز',
            value: 'لپ‌تاپ اداری',
            fieldtype: 'Data',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
          const WorkflowTaskDetailPage(task: 'WFT-2026-00042'),
          _Repo(detail: detail)));
      await tester.pumpAndSettle();
      await openTechnical(tester);

      expect(find.text('لپ‌تاپ اداری'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
