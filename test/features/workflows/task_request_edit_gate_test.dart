import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'request_fixtures.dart';

/// A client that answers `get_request` with the server's `can_edit` flag,
/// copied from the real `get_request` response shape.
class _Client extends Fake implements FrappeApiClient {
  _Client(this.canEdit);
  final bool canEdit;
  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async =>
      const FrappeUserContext(userId: 'approver', fullName: 'تأییدکننده', roles: ['HR Manager']);
  @override
  Future<dynamic> callAsoudMethod(String method, {Map<String, dynamic>? data}) async {
    if (method.endsWith('workflow_request.get_request')) {
      return {
        ...Map<String, dynamic>.from(requestData('get_request_purchase') as Map),
        'can_edit': canEdit,
        'can_cancel': false,
        'viewer': {'is_requester': canEdit, 'open_task': null},
      };
    }
    if (method.endsWith('workflow_request.request_options')) {
      return <Map<String, dynamic>>[];
    }
    if (method.endsWith('workflow.list_workflows')) {
      return <Map<String, dynamic>>[];
    }
    throw UnimplementedError(method);
  }
}

class _Tasks extends Fake implements WorkflowTaskRepository {
  _Tasks(this.detail);
  final WorkflowTaskDetail detail;
  @override
  bool get isOfflinePreview => false;
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => detail;
}

/// The stage's document_access is [documentAccess]; the server's can_edit is
/// the only thing that should decide whether the request is editable.
WorkflowTaskDetail _task(String documentAccess) => WorkflowTaskDetail(
      task: const WorkflowTask(
          id: 'T-1', instance: 'I-1', stage: 'S', title: 'تأیید', status: 'Open'),
      stageType: 'Approval',
      requestName: 'PR-1',
      requestCompany: 'شرکت آزمایشی',
      documentAccess: documentAccess,
    );

Future<void> _open(WidgetTester tester, bool canEdit, String documentAccess) async {
  final client = _Client(canEdit);
  await tester.pumpWidget(
      RepositoryProvider<WorkflowTaskRepository>.value(
          value: _Tasks(_task(documentAccess)),
          child: RepositoryProvider<FrappeApiClient>.value(
              value: client,
              child: MaterialApp(
                theme: AsoudTheme.light,
                builder: (context, child) =>
                    Directionality(textDirection: TextDirection.rtl, child: child!),
                home: const WorkflowTaskDetailPage(task: 'T-1'),
              ))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('مشاهده درخواست'));
  await tester.pumpAndSettle();
}

void main() {
  // The request detail page loads through the real repository, whose offline
  // store uses sqflite; the live binding lets that I/O complete.
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('a non-owner approver cannot edit the request ($width)',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, false, 'Edit');
      // The server's can_edit is false, so no edit or cancel control shows,
      // even though the stage's document_access is Edit.
      expect(find.text('ویرایش'), findsNothing);
      expect(find.text('انصراف درخواست'), findsNothing);
      expect(find.text('کپی لینک'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the requester can edit the request ($width)', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // The stage's document_access is Read Only, but the server grants the
      // requester can_edit; the server flag must win, not the stage access.
      await _open(tester, true, 'Read Only');
      expect(find.text('ویرایش'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
