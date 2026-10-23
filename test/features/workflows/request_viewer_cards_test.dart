import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_viewer_cards.dart';

class _Tasks implements WorkflowTaskRepository {
  final calls = <Map<String, Object?>>[];
  @override
  Future<void> completeTask({
    required String task,
    required String action,
    String? comment,
    Map<String, dynamic> response = const {},
  }) async =>
      calls.add({'task': task, 'action': action, 'comment': comment});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _data({Map<String, dynamic>? task, bool requester = false}) => {
      'status_key': 'in_review',
      'viewer': {
        'is_requester': requester,
        'open_task': task == null
            ? null
            : {
                'name': 'TASK-1',
                'stage_title': 'تأیید مدیر',
                'stage_type': 'Approval',
                'approve_action': 'Approve',
                'allow_reject': true,
                'allow_return': false,
                'comment_required': false,
                'reject_comment_required': true,
                'has_form': false,
                ...task,
              },
      },
    };

Future<void> _pump(WidgetTester tester, double width, Map<String, dynamic> data,
    _Tasks tasks, VoidCallback onDecided) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Scaffold(
        body: SingleChildScrollView(
            child: RequestViewerCards(
                data: data, tasks: tasks, onDecided: onDecided))),
  ));
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('requester sees the status message at $width', (tester) async {
      await _pump(tester, width, _data(requester: true), _Tasks(), () {});
      expect(find.text('وضعیت درخواست من'), findsOneWidget);
      expect(find.text('درخواست شما در انتظار بررسی مسئول مربوط است.'),
          findsOneWidget);
      expect(find.text('اقدام'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('self approval explanation replaces the action card', (tester) async {
    final data = _data(task: {}, requester: true);
    final viewer = data['viewer'] as Map<String, dynamic>;
    viewer['self_approval_blocked'] = true;
    viewer['open_task'] = null;
    await _pump(tester, 320, data, _Tasks(), () {});
    expect(find.text('تأیید درخواست خودتان مجاز نیست.'), findsOneWidget);
    expect(find.text('اقدام'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handler sees only the allowed buttons; reject needs a reason and sends once',
      (tester) async {
    final tasks = _Tasks();
    var decided = 0;
    await _pump(tester, 320, _data(task: {}), tasks, () => decided++);
    expect(find.text('وضعیت درخواست من'), findsNothing);
    expect(find.text('تأیید'), findsOneWidget);
    expect(find.text('رد'), findsOneWidget);
    expect(find.text('بازگرداندن'), findsNothing);

    await tester.tap(find.text('رد'));
    await tester.pumpAndSettle();
    var submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'رد').last);
    expect(submit.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'مقدور نیست');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'رد').last);
    await tester.pumpAndSettle();
    expect(tasks.calls, [
      {'task': 'TASK-1', 'action': 'Reject', 'comment': 'مقدور نیست'}
    ]);
    expect(decided, 1);
  });

  testWidgets('reject needs a reason even when an old stage flag is false', (tester) async {
    await _pump(tester, 320,
        _data(task: {'reject_comment_required': false}), _Tasks(), () {});
    await tester.tap(find.text('رد'));
    await tester.pumpAndSettle();
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'رد').last);
    expect(submit.onPressed, isNull);
    expect(find.text('دلیل (الزامی)'), findsOneWidget);
  });

  testWidgets('approve is sent without a reason when none is required', (tester) async {
    final tasks = _Tasks();
    await _pump(tester, 390, _data(task: {}), tasks, () {});
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تأیید').last);
    await tester.pumpAndSettle();
    expect(tasks.calls, [
      {'task': 'TASK-1', 'action': 'Approve', 'comment': null}
    ]);
  });

  testWidgets('a stage with a form offers the task page instead of buttons', (tester) async {
    await _pump(tester, 390, _data(task: {'has_form': true}), _Tasks(), () {});
    expect(find.text('ثبت اطلاعات و تصمیم'), findsOneWidget);
    expect(find.text('رد'), findsNothing);
  });
}
