import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_instance_detail_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_manual_start_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workflow_start_settings_test.dart' as fixtures;

class InstanceClient extends Fake implements FrappeClient {
  bool allowed = false;
  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) async =>
      {
        'name': 'instance',
        'subject': 'بررسی قرارداد',
        'status': 'Completed',
        'workflow_definition': 'definition',
        'reference_doctype': 'ASOUD Form Entry',
        'reference_name': 'entry',
        'can_restart': allowed,
        'activities': <dynamic>[],
      };
}

void main() {
  test('restart eligibility comes only from the real detail response flag',
      () async {
    final client = InstanceClient();
    final repository = FrappeWorkflowTaskRepository(client);
    expect((await repository.getInstance('instance')).canRestart, isFalse);
    client.allowed = true;
    expect((await repository.getInstance('instance')).canRestart, isTrue);
    expect(
        const WorkflowInstanceDetail(
                summary: WorkflowInstanceSummary(
                    id: 'old', subject: 'قبلی', status: 'Completed'))
            .canRestart,
        isFalse);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'closed referenced restart requires a fresh reason and sends the original identity at $width RTL',
        (tester) async {
      tester.view.physicalSize = Size(width, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = fixtures.Client();
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: WorkflowManualStartDialog(
              definition: 'definition',
              client: client,
              restarting: true,
              initialSubject: 'بررسی قرارداد',
              referenceDoctype: 'ASOUD Form Entry',
              referenceName: 'entry')));
      await tester.tap(find.text('شروع مجدد با ثبت علت'));
      await tester.pumpAndSettle();
      expect(client.calls, 0);
      await tester.enterText(find.byType(TextField).last, 'بازبینی مدیریتی');
      await tester.tap(find.text('شروع مجدد با ثبت علت'));
      await tester.pumpAndSettle();
      expect(client.calls, 1);
      expect(client.sent!['definition'], 'definition');
      expect(client.sent!['subject'], 'بررسی قرارداد');
      expect(client.sent!['reason'], 'بازبینی مدیریتی');
      expect(client.sent!['reference_doctype'], 'ASOUD Form Entry');
      expect(client.sent!['reference_name'], 'entry');
      expect(client.sent!['restart'], 1);
      expect(client.sent!['request_id'], isA<String>());
      expect(client.sent!['request_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'instance detail hides restart without server authority at $width RTL',
        (tester) async {
      tester.view.physicalSize = Size(width, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = InstanceClient();
      final repository = FrappeWorkflowTaskRepository(client);
      for (final allowed in [false, true]) {
        client.allowed = allowed;
        await tester.pumpWidget(
            RepositoryProvider<WorkflowTaskRepository>.value(
                value: repository,
                child: MaterialApp(
                    theme: AsoudTheme.light,
                    builder: (_, child) => Directionality(
                        textDirection: TextDirection.rtl, child: child!),
                    home: const WorkflowInstanceDetailPage(
                        instance: 'instance'))));
        await tester.pumpAndSettle();
        expect(find.text('شروع مجدد با ثبت علت'),
            allowed ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
