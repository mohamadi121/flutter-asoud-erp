import 'dart:convert';
import 'dart:io';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_returned_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

/// `get_request` of a returned request and `get_workflow_instance` after the owner
/// resubmitted it, both captured from the backend integration test.
Map<String, dynamic> _returned() => Map<String, dynamic>.from(
    requestData('get_request_returned') as Map);

class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.detailMap, [this.types = const []]);
  final Map<String, dynamic> detailMap;
  final List<Map<String, dynamic>> types;

  @override
  Future<Map<String, dynamic>> detail(String name) async =>
      Map<String, dynamic>.from(detailMap);

  @override
  Future<List<Map<String, dynamic>>> options() async => types;

  @override
  Future<List<RequestComment>> comments(String name) async => const [];
}

class _Tasks extends Fake implements WorkflowTaskRepository {
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async {
    final raw = jsonDecode(File(
                'test/fixtures/requests/get_workflow_instance_resubmitted.json')
            .readAsStringSync())
        as Map;
    return WorkflowInstanceDetail(
      summary: const WorkflowInstanceSummary(
          id: 'WFI-1', subject: 'درخواست', status: 'Running'),
      activities: [
        for (final row in raw['activities'] as List)
          WorkflowTaskActivity(
            actor: '${(row as Map)['actor']}',
            action: '${row['action']}',
            comment: '${row['comment'] ?? ''}',
            createdOn: DateTime.tryParse('${row['created_on']}'),
            stageTitle: '${row['stage_title'] ?? ''}',
            actorName: '${row['actor_name'] ?? ''}',
            before: Map<String, dynamic>.from(row['before'] as Map? ?? {}),
            after: Map<String, dynamic>.from(row['after'] as Map? ?? {}),
            labels: Map<String, String>.from(row['labels'] as Map? ?? {}),
          ),
      ],
    );
  }
}

Future<void> _open(WidgetTester tester, Map<String, dynamic> data,
    {double width = 390, List<Map<String, dynamic>> options = const []}) async {
  await tester.binding.setSurfaceSize(Size(width, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RequestDetailScaffold(
          repository: _Repo(data, options),
          tasks: _Tasks(),
          name: '${data['name']}',
          title: 'جزئیات درخواست'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RequestScreenRegistry.clear);

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('a returned request shows the reason and the button at $width',
        (tester) async {
      await _open(tester, _returned(), width: width);
      expect(find.byKey(const ValueKey('request-returned-banner')),
          findsOneWidget);
      expect(find.text('برای اصلاح بازگردانده شد'), findsOneWidget);
      expect(find.text('دلیل: مبلغ را اصلاح کنید'), findsOneWidget);
      expect(find.text('اصلاح درخواست'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('«اصلاح درخواست» opens the form with the existing request',
      (tester) async {
    Map<String, dynamic>? seenType, seenExisting;
    RequestScreenRegistry.register(
        'purchase',
        RequestTemplateScreens(form: (context, repository, type, existing) {
          seenType = type;
          seenExisting = existing;
          return const Scaffold(body: Text('فرم اصلاح'));
        }));
    final data = _returned();
    await _open(tester, data, options: [
      {'name': data['workflow_definition'], 'template_key': 'purchase'}
    ]);
    await tester.tap(find.byKey(const ValueKey('request-correct-button')));
    await tester.pumpAndSettle();
    expect(find.text('فرم اصلاح'), findsOneWidget);
    expect(seenType!['name'], data['workflow_definition']);
    expect(seenExisting!['name'], data['name']);
    expect(seenExisting!['status_key'], 'returned');
  });

  testWidgets('the button is hidden when the server does not allow editing',
      (tester) async {
    await _open(tester, {..._returned(), 'can_edit': false});
    expect(find.text('دلیل: مبلغ را اصلاح کنید'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-correct-button')), findsNothing);
  });

  testWidgets('there is no banner in any other state', (tester) async {
    await _open(tester, {
      ..._returned(),
      'status_key': 'in_review',
      'return_reason': '',
      'can_edit': false
    });
    expect(find.byKey(const ValueKey('request-returned-banner')), findsNothing);
  });

  testWidgets('the history row «اصلاح و ارسال مجدد» lists the old and new value',
      (tester) async {
    await _open(tester, {..._returned(), 'status_key': 'in_review'});
    await tester.tap(find.text('سوابق'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اصلاح و ارسال مجدد'), findsWidgets);
    // The change is a line of its own (activity before/after), not a quoted comment.
    expect(find.text('دلیل: دلیل اولیه ← دلیل اصلاح‌شده'), findsOneWidget);
    expect(find.textContaining('{"changes"'), findsNothing);
  });

  test('an activity shows its comment, then one line per changed field', () {
    expect(
        requestActivityComment(const WorkflowTaskActivity(
            actor: 'a', action: 'Return', comment: 'علت')),
        'علت');
    expect(
        requestActivityComment(const WorkflowTaskActivity(
            actor: 'a',
            action: 'Resubmitted',
            before: {'a': ''},
            after: {'a': '۲'},
            labels: {'a': 'الف'})),
        'الف: — ← ۲');
    // The form label wins over the stored one; without either a Persian word is shown.
    expect(
        requestActivityComment(
            const WorkflowTaskActivity(
                actor: 'a',
                action: 'Resubmitted',
                before: {'b': '۱'},
                after: {'b': '۲'}),
            labelOf: (key) => null),
        'مقدار: ۱ ← ۲');
  });
}
