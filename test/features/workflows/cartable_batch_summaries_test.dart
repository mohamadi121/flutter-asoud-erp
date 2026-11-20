import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/cartable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements FrappeApiClient {}

/// A repository that answers the missing-instance summaries through the batch
/// method (PA-032) and records what it was asked for.
class _BatchTasks implements WorkflowTaskRepository, WorkflowInstanceSummariesRepository {
  _BatchTasks(this.open);
  final List<WorkflowTask> open;
  final List<String> batchRequests = [];

  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      status == 'Open' ? open : const [];

  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [
        WorkflowInstanceSummary(
            id: 'WFI-9', subject: 'درخواست تجهیزات', status: 'Completed'),
      ];

  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();

  @override
  Future<List<WorkflowInstanceSummary>> getInstanceSummaries(
      List<String> names) async {
    batchRequests.addAll(names);
    // The server returns only the accessible summaries; here both are readable.
    return [
      WorkflowInstanceSummary(
          id: 'WFI-1',
          subject: 'درخواست خرید لپ‌تاپ',
          status: 'Running',
          currentStageTitle: 'بررسی'),
      WorkflowInstanceSummary(
          id: 'WFI-2',
          subject: 'درخواست مرخصی',
          status: 'Running',
          currentStageTitle: 'تأیید'),
    ];
  }

  @override
  Future<WorkflowTaskDetail> getTask(String task) async =>
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

Future<_BatchTasks> _pump(WidgetTester tester, double width) async {
  // Tall enough that both lazy cards are built, not just the first.
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = _Api();
  when(() => api.isAuthenticated).thenReturn(true);
  when(() => api.getCurrentUser()).thenAnswer((_) async =>
      const FrappeUserContext(
          userId: 'employee@example.com', fullName: 'کارمند', roles: []));
  when(() => api.callAsoudMethod(any(), data: any(named: 'data')))
      .thenAnswer((_) async => throw StateError('directives are not part of this test'));
  final repository = _BatchTasks(const [
    WorkflowTask(
        id: 'WFT-1',
        instance: 'WFI-1',
        stage: 'S-1',
        title: 'بررسی',
        status: 'Open'),
    WorkflowTask(
        id: 'WFT-2',
        instance: 'WFI-2',
        stage: 'S-1',
        title: 'تأیید',
        status: 'Open'),
  ]);
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: api),
      RepositoryProvider<WorkflowTaskRepository>.value(value: repository),
    ],
    child: MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const CartablePage(company: 'شرکت'),
    ),
  ));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('the cartable renders batch summaries without overflow at $width',
        (tester) async {
      final repository = await _pump(tester, width);
      // Both incoming instances were resolved through the batch method.
      expect(repository.batchRequests, ['WFI-1', 'WFI-2']);
      // The batch summaries drive the card titles and statuses.
      expect(find.text('درخواست خرید لپ‌تاپ'), findsOneWidget);
      expect(find.text('درخواست مرخصی'), findsOneWidget);
      expect(find.text('وضعیت: در حال گردش'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an omitted batch summary leaves the card, not the page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api();
    when(() => api.isAuthenticated).thenReturn(true);
    when(() => api.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'employee@example.com', fullName: 'کارمند', roles: []));
    when(() => api.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => throw StateError('directives are not part of this test'));
    // The server omits WFI-2 (inaccessible); the page must still render.
    final repository = _OmittingBatchTasks();
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: api),
        RepositoryProvider<WorkflowTaskRepository>.value(value: repository),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const CartablePage(company: 'شرکت'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('درخواست خرید لپ‌تاپ'), findsOneWidget);
    // The unavailable record is reported, not silently dropped.
    expect(find.textContaining('وضعیت گردش برخی دریافتی‌ها قابل دریافت نیست'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OmittingBatchTasks implements WorkflowTaskRepository, WorkflowInstanceSummariesRepository {
  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      status == 'Open'
          ? const [
              WorkflowTask(
                  id: 'WFT-1',
                  instance: 'WFI-1',
                  stage: 'S-1',
                  title: 'بررسی',
                  status: 'Open'),
              WorkflowTask(
                  id: 'WFT-2',
                  instance: 'WFI-2',
                  stage: 'S-1',
                  title: 'تأیید',
                  status: 'Open'),
            ]
          : const [];
  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances({String? status}) async =>
      const [];
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();
  @override
  Future<List<WorkflowInstanceSummary>> getInstanceSummaries(
      List<String> names) async {
    // WFI-2 is inaccessible, so the server omits it.
    return names
        .where((n) => n != 'WFI-2')
        .map((n) => WorkflowInstanceSummary(
            id: n,
            subject: n == 'WFI-1' ? 'درخواست خرید لپ‌تاپ' : '',
            status: 'Running'))
        .toList();
  }

  @override
  Future<WorkflowTaskDetail> getTask(String task) async =>
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
