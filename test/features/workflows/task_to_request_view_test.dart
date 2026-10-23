import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/request_flow_pages.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

class _Requests extends Fake implements GenericRequestRepository {
  @override
  Future<Map<String, dynamic>> detail(String name) async => {
        ...Map<String, dynamic>.from(requestData('get_request_purchase') as Map),
        'can_edit': true,
        'can_cancel': true,
        'viewer': {
          'is_requester': true,
          'open_task': {
            'name': 'T-1',
            'stage_title': 'تأیید مدیر',
            'stage_type': 'Approval',
            'approve_action': 'Approve',
            'allow_reject': true,
            'allow_return': false,
            'comment_required': false,
            'reject_comment_required': false,
            'has_form': false,
          },
        },
      };

  @override
  Future<List<Map<String, dynamic>>> options() async => requestOptionFixtures();

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

  @override
  Future<List<RequestComment>> comments(String name) async => const [];
}

class _Tasks extends Fake implements WorkflowTaskRepository {
  _Tasks(this.detail);
  final WorkflowTaskDetail detail;
  @override
  bool get isOfflinePreview => false;
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;
}

WorkflowTaskDetail _task(String requestName) => WorkflowTaskDetail(
      task: const WorkflowTask(
          id: 'T-1', instance: 'I-1', stage: 'S', title: 'تأیید', status: 'Open'),
      stageType: 'Approval',
      requestName: requestName,
      requestCompany: 'شرکت آزمایشی',
    );

Future<void> _pump(WidgetTester tester, double width, Widget home,
    {WorkflowTaskRepository? tasks}) async {
  await tester.binding.setSurfaceSize(Size(width, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox()); // a fresh page per call
  Widget app = MaterialApp(
    theme: AsoudTheme.light,
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: home,
  );
  if (tasks != null) {
    app = RepositoryProvider<WorkflowTaskRepository>.value(
        value: tasks, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in const [320.0, 390.0, 430.0]) {
    testWidgets('the request button shows only with a request name ($width)',
        (tester) async {
      await _pump(tester, width,
          const WorkflowTaskDetailPage(task: 'T-1'),
          tasks: _Tasks(_task('PR-1')));
      expect(find.text('مشاهده درخواست'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _pump(tester, width,
          const WorkflowTaskDetailPage(task: 'T-1'),
          tasks: _Tasks(_task('')));
      expect(find.text('مشاهده درخواست'), findsNothing);
    });

    testWidgets('read-only request has no edit, cancel or decision ($width)',
        (tester) async {
      await _pump(tester, width,
          RequestDetailPage(
              name: 'PR-1',
              repository: _Requests(),
              tasks: _Tasks(_task('PR-1'))));
      expect(find.text('اقدام'), findsOneWidget);
      expect(find.text('ویرایش'), findsOneWidget);
      await _pump(tester, width,
          RequestDetailPage(
              name: 'PR-1',
              repository: _Requests(),
              tasks: _Tasks(_task('PR-1')),
              readOnly: true));
      expect(find.text('اقدام'), findsNothing);
      expect(find.text('وضعیت درخواست من'), findsNothing);
      expect(find.text('ویرایش'), findsNothing);
      expect(find.text('انصراف درخواست'), findsNothing);
      expect(find.text('کپی لینک'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
