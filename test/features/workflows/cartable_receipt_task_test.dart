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

class _Tasks implements WorkflowTaskRepository {
  _Tasks(this.open);
  final List<WorkflowTask> open;

  @override
  bool get isOfflinePreview => false;
  @override
  Future<List<WorkflowTask>> getMyTasks({String status = 'Open'}) async =>
      status == 'Open' ? open : const [];
  @override
  Future<List<WorkflowInstanceSummary>> getMyInstances(
          {String? status}) async =>
      const [
        WorkflowInstanceSummary(
            id: 'WFI-9', subject: 'درخواست تجهیزات', status: 'Completed'),
      ];
  @override
  Future<WorkflowInstanceDetail> getInstance(String instance) async =>
      throw UnimplementedError();
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

Future<void> _pump(WidgetTester tester, double width, WorkflowTask task) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = _Api();
  when(() => api.isAuthenticated).thenReturn(true);
  when(() => api.getCurrentUser()).thenAnswer((_) async =>
      const FrappeUserContext(
          userId: 'employee@example.com', fullName: 'کارمند', roles: []));
  when(() => api.callAsoudMethod(any(), data: any(named: 'data')))
      .thenAnswer((_) async => throw StateError('directives are not part of this test'));
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: api),
      RepositoryProvider<WorkflowTaskRepository>.value(value: _Tasks([task])),
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
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('the receipt task card names the equipment at $width',
        (tester) async {
      await _pump(
          tester,
          width,
          const WorkflowTask(
            id: 'WFT-9',
            instance: 'WFI-9',
            stage: 'S-END',
            title: 'تأیید دریافت تجهیز: لپ‌تاپ اداری',
            status: 'Open',
            followup: 'confirm_receipt',
          ));
      expect(find.text('تأیید دریافت تجهیز: لپ‌تاپ اداری'), findsOneWidget);
      expect(find.text('درخواست تجهیزات'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an ordinary task keeps the request subject as the card title',
      (tester) async {
    await _pump(
        tester,
        390,
        const WorkflowTask(
            id: 'WFT-1',
            instance: 'WFI-9',
            stage: 'S-1',
            title: 'بررسی',
            status: 'Open'));
    expect(find.text('درخواست تجهیزات'), findsOneWidget);
  });
}
