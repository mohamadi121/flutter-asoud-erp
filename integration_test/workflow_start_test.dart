import 'package:asoud_erp/main.dart' as app;
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

// Opt-in only: a disposable, inactive, v1 Manual workflow with no executions.
// This saves its existing configuration, never starts a production execution.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const definition = String.fromEnvironment('ASOUD_E2E_START_DEFINITION');
  const writes = bool.fromEnvironment('ASOUD_E2E_ALLOW_WRITES');
  testWidgets(
      'real Start save and reopening the same form from the existing circle',
      (tester) async {
    app.main();
    await waitFor(tester, find.byKey(const Key('username_field')));
    await tester.enterText(
        find.widgetWithText(TextField, 'نشانی سرور'), E2e.url);
    await tester.enterText(find.byKey(const Key('username_field')), E2e.user);
    await tester.enterText(
        find.byKey(const Key('password_field')), E2e.password);
    await tapVisible(tester, find.byKey(const Key('login_button')));
    await waitFor(tester, find.text('خانه'));
    final context = tester.element(find.text('خانه').first);
    final repository = context.read<WorkflowRepository>();
    final before = await repository.getDesign(definition);
    final start =
        before.stages.singleWhere((stage) => stage.type.name == 'start');
    expect(start.config['start_settings_version'], 1);
    expect(start.config['trigger_type'], 'Manual');
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => WorkflowFormPage(existing: before.workflow)))
        .ignore();
    await waitFor(tester, find.byKey(const ValueKey('workflow-start-manual')));
    await tapVisible(tester, find.text('ذخیره تغییرات'));
    await waitFor(tester, find.text('خانه'));
    final after = await repository.getDesign(definition);
    expect(after.stages.singleWhere((stage) => stage.type.name == 'start').id,
        start.id);
    expect(
        after.stages
            .singleWhere((stage) => stage.type.name == 'start')
            .config['trigger_type'],
        'Manual');
    expect(after.stages.length, before.stages.length);
    if (!context.mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => WorkflowDesignerPage(definition: definition)))
        .ignore();
    await tapVisible(tester, find.byKey(ValueKey('workflow-node-${start.id}')));
    await waitFor(tester, find.byType(WorkflowFormPage));
    expect(find.text('ذخیره تغییرات'), findsOneWidget);
  },
      skip: E2e.skipReason != null || definition.isEmpty || !writes,
      timeout: const Timeout(Duration(minutes: 4)));
}
