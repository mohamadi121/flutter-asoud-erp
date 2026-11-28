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

/// A repository whose incoming instances resolve through the batch method to
/// one Failed+Stopped instance and one plain Failed instance, so the cartable
/// must show «متوقف شد» for the first and «ناموفق» for the second.
class _StoppedTasks implements WorkflowTaskRepository,
    WorkflowInstanceSummariesRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      status == 'Open'
          ? const [
              WorkflowTask(
                  id: 'WFT-STOP',
                  instance: 'WFI-STOP',
                  stage: 'S-1',
                  title: 'بررسی',
                  status: 'Open'),
              WorkflowTask(
                  id: 'WFT-FAIL',
                  instance: 'WFI-FAIL',
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
    return names
        .map((n) => WorkflowInstanceSummary(
            id: n,
            subject: n == 'WFI-STOP' ? 'درخواست متوقف‌شده' : 'درخواست ناموفق',
            status: 'Failed',
            endOutcome: n == 'WFI-STOP' ? 'Stopped' : ''))
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

Future<void> _pump(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = _Api();
  when(() => api.isAuthenticated).thenReturn(true);
  when(() => api.getCurrentUser()).thenAnswer((_) async =>
      const FrappeUserContext(
          userId: 'employee@example.com', fullName: 'کارمند', roles: []));
  when(() => api.callAsoudMethod(any(), data: any(named: 'data')))
      .thenAnswer((_) async =>
          throw StateError('directives are not part of this test'));
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: api),
      RepositoryProvider<WorkflowTaskRepository>.value(
          value: _StoppedTasks()),
    ],
    child: MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const CartablePage(company: 'شرکت'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the cartable shows متوقف شد for a Failed+Stopped instance and ناموفق for a plain Failed one',
      (tester) async {
    for (final width in [320.0, 390.0]) {
      await _pump(tester, width);
      // The designed Stop outcome is labelled «متوقف شد», not «ناموفق».
      expect(find.text('وضعیت: متوقف شد'), findsOneWidget);
      // A regular Failed instance keeps «ناموفق».
      expect(find.text('وضعیت: ناموفق'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
