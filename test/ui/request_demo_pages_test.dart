import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_tasks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

class _OfflineTasks extends Fake implements WorkflowTaskRepository {
  static const error =
      ApiException(kind: ApiFailureKind.network, message: 'offline');
  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) =>
      throw error;
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) => throw error;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) =>
      throw error;
  @override
  Future<WorkflowTaskDetail> getTask(String task) => throw error;
  @override
  Future<void> saveDraft(String task, Map<String, dynamic> values) =>
      throw error;
  @override
  Future<String> uploadAttachment(
          {required String task,
          required String filename,
          required List<int> bytes}) =>
      throw error;
  @override
  Future<void> completeTask(
          {required String task,
          required String action,
          String? comment,
          Map<String, dynamic> response = const {}}) =>
      throw error;
}

Widget _app(Widget page, WorkflowTaskRepository tasks) =>
    RepositoryProvider<WorkflowTaskRepository>.value(
      value: tasks,
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: page,
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  testWidgets('preview requests list renders the demo statuses at 390',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = GenericRequestRepository(client, 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());
    final tasks = PreviewWorkflowTaskRepository(_OfflineTasks());
    await tester.pumpWidget(_app(
        GenericRequestsPage(company: 'شرکت نمونه آسود', repository: repository),
        tasks));
    await tester.pumpAndSettle();

    expect(find.text('مأموریت تهران — نمایشگاه'), findsOneWidget);
    expect(find.text('تنخواه خرداد واحد فروش'), findsOneWidget);
    expect(find.text('در انتظار تأیید'), findsOneWidget);
    expect(find.text('رد شده'), findsWidgets); // the tab and a status chip
    expect(find.text('تکمیل شده'), findsWidgets);

    await tester.tap(find.text('مأموریت تهران — نمایشگاه'));
    await tester.pumpAndSettle();
    expect(find.text('جزئیات درخواست'), findsOneWidget);
    expect(find.text('دعوت‌نامه نمایشگاه.pdf'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('گردش فرایند'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('گردش فرایند'), findsOneWidget);
    expect(find.text('«با مأموریت موافقت شد.»'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview cartable renders the demo user tasks at 390',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const WorkflowTasksPage(),
        PreviewWorkflowTaskRepository(_OfflineTasks())));
    await tester.pumpAndSettle();

    expect(find.text('تأیید مرخصی سارا محمدی'), findsOneWidget);
    expect(find.text('بررسی درخواست خرید لپ‌تاپ'), findsOneWidget);
    expect(find.text('اصلاح تنخواه خرداد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
