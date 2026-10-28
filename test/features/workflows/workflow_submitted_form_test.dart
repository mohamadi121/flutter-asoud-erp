import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_task.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_task_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_task_detail_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
}

class Tasks extends Fake implements WorkflowTaskRepository {
  @override
  bool get isOfflinePreview => false;
  @override
  Future<WorkflowTaskDetail> getTask(String task) async => const WorkflowTaskDetail(
      task: WorkflowTask(id: 'task', instance: 'instance', stage: 'stage',
          title: 'بررسی درخواست اصلی', status: 'Open'),
      stageType: 'User Task', submittedForm: {'company': 'دفتر',
        'schema': {'kind': 'Request', 'sections': [{'id': 'main', 'fields': [
          {'key': 'note', 'label': 'توضیح', 'type': 'Text'}]}]},
        'values': {'note': 'اطلاعات ارسال‌شده'}});
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('submitted source is read-only and separate from task response at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MultiRepositoryProvider(providers: [
        RepositoryProvider<FrappeApiClient>.value(value: Client()),
        RepositoryProvider<WorkflowTaskRepository>.value(value: Tasks()),
      ], child: MaterialApp(theme: AsoudTheme.light,
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const WorkflowTaskDetailPage(task: 'task'))));
      await tester.pumpAndSettle();
      final view = tester.widget<FormFieldsView>(find.byType(FormFieldsView));
      expect(view.enabled, isFalse);
      expect(view.snapshot, isTrue);
      expect(view.values['note'], 'اطلاعات ارسال‌شده');
      final cubit = tester.element(find.byType(FormFieldsView)).read<WorkflowTaskDetailCubit>();
      expect(cubit.state.values, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
