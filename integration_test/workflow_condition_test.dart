import 'package:asoud_erp/main.dart' as app;
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

// Explicit opt-in: use only a disposable inactive v2 definition with no runs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const definition = String.fromEnvironment('ASOUD_E2E_CONDITION_DEFINITION');
  const writes = bool.fromEnvironment('ASOUD_E2E_ALLOW_WRITES');
  testWidgets('real condition save and reopen preserves rules and native routes', (tester) async {
    app.main();
    await waitFor(tester, find.byKey(const Key('username_field')));
    await tester.enterText(find.widgetWithText(TextField, 'نشانی سرور'), E2e.url);
    await tester.enterText(find.byKey(const Key('username_field')), E2e.user);
    await tester.enterText(find.byKey(const Key('password_field')), E2e.password);
    await tapVisible(tester, find.byKey(const Key('login_button')));
    await waitFor(tester, find.text('خانه'));
    final context = tester.element(find.text('خانه').first);
    final repository = context.read<WorkflowRepository>();
    final before = await repository.getDesign(definition);
    expect(before.workflow.status.name, 'inactive');
    final stage = before.stages.firstWhere((row) => row.config['condition_version'] == 2);
    final cubit = WorkflowDesignerCubit(repository: repository, definition: definition);
    addTearDown(cubit.close);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(
      value: cubit, child: WorkflowStageSettingsPage(stage: stage, roles: const [])))).ignore();
    await waitFor(tester, find.text('۱. تعریف شروط'));
    await tapVisible(tester, find.text('تأیید تنظیمات شرط و مسیر'));
    await waitFor(tester, find.text('خانه'));
    final after = await repository.getDesign(definition);
    final stored = after.stages.singleWhere((row) => row.id == stage.id);
    expect(stored.config['conditions'], stage.config['conditions']);
    expect(stored.config['combine'], stage.config['combine']);
    expect(after.transitions, before.transitions);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BlocProvider.value(
      value: cubit, child: WorkflowStageSettingsPage(stage: stored, roles: const [])))).ignore();
    await waitFor(tester, find.text('۱. تعریف شروط'));
    expect(tester.takeException(), isNull);
  }, skip: E2e.skipReason != null || definition.isEmpty || !writes,
    timeout: const Timeout(Duration(minutes: 4)));
}
