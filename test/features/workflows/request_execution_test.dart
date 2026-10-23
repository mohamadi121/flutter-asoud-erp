import 'dart:convert';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_execution_card.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_print.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_viewer_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'request_fixtures.dart';

// The block and its labels are those of `services/request_execution.py`
// (docs/api/request_templates.md, «Execution lane»).
Map<String, dynamic> _block(String state, String label,
        {String error = '', String reference = ''}) =>
    {
      'state': state,
      'label': label,
      'error': error,
      'executed_on': state == 'succeeded' ? '2026-10-07 09:30:00' : '',
      'executed_by_name': state == 'succeeded' ? 'علی رضایی' : '',
      'reference': reference,
    };

final _blocks = {
  'not_started': _block('not_started', 'تأیید شده، اجرا انجام نشده'),
  'pending': _block('pending', 'در انتظار اجرا'),
  'succeeded': _block('succeeded', 'اجرا انجام شد', reference: 'HR-LAP-0001'),
  'failed': _block('failed', 'اجرا ناموفق بود؛ درخواست تأیید شده است',
      error: 'LEAVE_BALANCE: مانده مرخصی کافی نیست'),
  'needs_review': _block('needs_review', 'نیازمند بررسی'),
  'not_connected':
      _block('not_connected', 'اجرای خودکار برای این نوع درخواست متصل نیست'),
};
const _done = 'اجرا انجام شد';

class _MockClient extends Mock implements FrappeClient {}

class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.detailMap);
  final Map<String, dynamic> detailMap;
  @override
  Future<Map<String, dynamic>> detail(String name) async =>
      Map<String, dynamic>.from(detailMap);
  @override
  Future<List<Map<String, dynamic>>> options() async => requestOptionFixtures();
  @override
  Future<List<RequestComment>> comments(String name) async => const [];
  @override
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
      String name,
      {bool thumbnail = false}) async {
    final data = requestData('get_attachment') as Map;
    return (
      filename: '${data['filename']}',
      contentType: '${data['content_type']}',
      bytes: base64Decode('${data['content_base64']}')
    );
  }
}

class _Tasks extends Fake implements WorkflowTaskRepository {
  _Tasks(this.activities);
  final List<WorkflowTaskActivity> activities;
  @override
  Future<WorkflowInstanceDetail> getInstance(String id) async =>
      WorkflowInstanceDetail(
        summary: WorkflowInstanceSummary(
            id: id, subject: 'خرید', status: 'Completed'),
        activities: activities,
      );
}

Map<String, dynamic> _approved(Map<String, dynamic>? execution) => {
      ...Map<String, dynamic>.from(requestData('get_request_purchase') as Map),
      'status_key': 'approved',
      'status_label': 'تأیید شده',
      'status': 'Completed',
      'can_edit': false,
      'can_cancel': false,
      if (execution != null) 'execution': execution,
    };

Future<void> _open(WidgetTester tester, Map<String, dynamic> data,
    {double width = 390, List<WorkflowTaskActivity> activities = const []}) async {
  await tester.binding.setSurfaceSize(Size(width, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RequestDetailScaffold(
          repository: _Repo(data),
          name: '${data['name']}',
          tasks: _Tasks(activities)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RequestScreenRegistry.clear);

  test('activity rows keep before/after; rows without them stay empty',
      () async {
    final client = _MockClient();
    // Shape of `get_workflow_instance.activities` (workflow_runtime.py).
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'name': 'WFI-1',
              'status': 'Running',
              'activities': [
                {
                  'actor': 'a@example.com',
                  'actor_name': 'سارا محمدی',
                  'action': 'Edited',
                  'comment': '',
                  'created_on': '2026-10-06 10:00:00',
                  'stage_title': 'ثبت',
                  'before': {'priority': 'Normal'},
                  'after': {'priority': 'High'},
                },
                {
                  'actor': 'b@example.com',
                  'action': 'Approve',
                  'created_on': '2026-10-06 11:00:00',
                  'before': {},
                  'after': {},
                },
              ],
            });
    final detail = await FrappeWorkflowTaskRepository(client).getInstance('WFI-1');
    expect(detail.activities.first.before, {'priority': 'Normal'});
    expect(detail.activities.first.after, {'priority': 'High'});
    expect(detail.activities.last.before, isEmpty);
  });

  group('model', () {
    test('parses the server block', () {
      final execution = RequestExecution.fromMap(_blocks['succeeded']);
      expect(execution.state, 'succeeded');
      expect(execution.reference, 'HR-LAP-0001');
      expect(execution.executedByName, 'علی رضایی');
      expect(execution.applicable, isTrue);
    });

    test('a missing or unknown block is not applicable', () {
      expect(RequestExecution.fromMap(null).applicable, isFalse);
      expect(RequestExecution.fromMap({'state': 'not_applicable'}).applicable,
          isFalse);
    });

    test('without a server label every state still has a Persian sentence', () {
      for (final state in _blocks.keys) {
        final sentence = RequestExecution.fromMap({'state': state}).sentence;
        expect(sentence, isNotEmpty, reason: state);
        expect(sentence, isNot(matches(RegExp('[A-Za-z_]'))), reason: state);
        if (state != 'succeeded') expect(sentence, isNot(contains(_done)));
      }
    });

    test('RequestDetail.fromMap keeps the block', () {
      final detail = RequestDetail.fromMap(_approved(_blocks['failed']));
      expect(detail.execution.state, 'failed');
      expect(RequestDetail.fromMap(_approved(null)).execution.applicable,
          isFalse);
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    group('card at $width', () {
      for (final entry in _blocks.entries) {
        testWidgets('${entry.key} shows its sentence', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(MaterialApp(
            theme: AsoudTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: RequestExecutionCard(
                          execution: RequestExecution.fromMap(entry.value)))),
            ),
          ));
          expect(find.text('عملیات اجرایی'), findsOneWidget);
          expect(find.text(entry.value['label'] as String), findsOneWidget);
          if (entry.key != 'succeeded') {
            expect(find.textContaining(_done), findsNothing);
          }
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('succeeded shows the reference and who executed it',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: RequestExecutionCard(
                    execution: RequestExecution.fromMap(_blocks['succeeded']))),
          ),
        ));
        expect(find.textContaining('HR-LAP-0001'), findsOneWidget);
        expect(find.textContaining('علی رضایی'), findsOneWidget);
        expect(find.textContaining('۱۴۰۵/۰۷/۱۵'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('the error is shown only when the server sent one',
      (tester) async {
    for (final error in ['LEAVE_BALANCE: مانده مرخصی کافی نیست', '']) {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: RequestExecutionCard(
                  execution: RequestExecution.fromMap(
                      {..._blocks['failed']!, 'error': error}))),
        ),
      ));
      expect(find.textContaining('مانده مرخصی کافی نیست'),
          error.isEmpty ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('a not applicable block renders nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: RequestExecutionCard(
              execution: RequestExecution.fromMap({'state': 'not_applicable'}))),
    ));
    expect(find.text('عملیات اجرایی'), findsNothing);
  });

  group('detail page', () {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('approved but not executed says so at $width', (tester) async {
        await _open(tester, _approved(_blocks['not_started']), width: width);
        expect(find.text('عملیات اجرایی'), findsOneWidget);
        // card + summary line
        expect(find.textContaining('تأیید شده، اجرا انجام نشده'),
            findsAtLeastNWidgets(2));
        expect(find.textContaining(_done), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a request without execution shows no card or line',
        (tester) async {
      await _open(tester, _approved({'state': 'not_applicable', 'label': ''}));
      expect(find.text('عملیات اجرایی'), findsNothing);
      await _open(tester, _approved(null));
      expect(find.text('عملیات اجرایی'), findsNothing);
      expect(find.textContaining('اجرا'), findsNothing);
    });

    testWidgets('the success sentence appears only for succeeded',
        (tester) async {
      await _open(tester, _approved(_blocks['succeeded']));
      expect(find.textContaining(_done), findsAtLeastNWidgets(2));
    });

    testWidgets('history shows the previous value then the new one',
        (tester) async {
      await _open(tester, _approved(null), activities: [
        WorkflowTaskActivity(
            actor: 'sara@example.com',
            actorName: 'سارا محمدی',
            action: 'Edited',
            stageTitle: 'ثبت درخواست',
            createdOn: DateTime(2026, 10, 6, 10),
            before: const {'priority': 'Normal'},
            after: const {'priority': 'High'}),
        WorkflowTaskActivity(
            actor: 'manager@example.com',
            actorName: 'علی رضایی',
            action: 'Approve',
            stageTitle: 'تأیید مدیر'),
      ]);
      await tester.tap(find.text('سوابق'));
      await tester.pumpAndSettle();
      expect(find.textContaining('←'), findsOneWidget);
      final line = tester.widget<Text>(find.textContaining('←')).data!;
      expect(line.indexOf('عادی'), lessThan(line.indexOf('←')));
      expect(line.indexOf('←'), lessThan(line.indexOf('مهم')));
      expect(line, isNot(contains('Normal')));
    });
  });

  group('requester message', () {
    String message(Map<String, dynamic> data) => requesterStatusMessage(
        '${data['status_key']}',
        execution: RequestExecution.fromMap(data['execution']));

    test('approval alone never says done', () {
      final text = message(
          {'status_key': 'approved', 'execution': _blocks['not_started']});
      expect(text, contains('تأیید شده، اجرا انجام نشده'));
      expect(text, isNot(contains(_done)));
    });

    test('succeeded says done', () {
      expect(
          message({'status_key': 'approved', 'execution': _blocks['succeeded']}),
          contains(_done));
    });

    test('without execution the old sentence is unchanged', () {
      expect(message({'status_key': 'approved'}),
          'درخواست شما تأیید شده است.');
    });
  });

  group('print', () {
    test('the execution state is printed as a row', () {
      expect(requestPrintExecution({'execution': _blocks['not_started']}),
          [
            ['وضعیت اجرا', 'تأیید شده، اجرا انجام نشده']
          ]);
    });

    test('a succeeded request prints the reference, a failed one no error', () {
      expect(requestPrintExecution({'execution': _blocks['succeeded']}), [
        ['وضعیت اجرا', _done],
        ['شماره سند اجرا', 'HR-LAP-0001'],
      ]);
      final failed = requestPrintExecution({'execution': _blocks['failed']});
      expect(failed.expand((row) => row).join(' '),
          isNot(contains('LEAVE_BALANCE')));
    });

    test('no block or not applicable prints nothing', () {
      expect(requestPrintExecution({}), isEmpty);
      expect(
          requestPrintExecution({'execution': {'state': 'not_applicable'}}),
          isEmpty);
    });
  });
}
