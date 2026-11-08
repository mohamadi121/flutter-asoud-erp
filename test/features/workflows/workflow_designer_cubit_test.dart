import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_designer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingStartRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static const definition = WorkflowDefinition(
    id: 'WF-1405-039',
    code: 'WF-1405-039',
    title: 'مرخصی تست',
    targetDoctype: 'Leave Application',
    status: WorkflowDefinitionStatus.inactive,
    isLocked: true,
    version: 1,
    stepsCount: 0,
    modified: null,
  );

  static const design = WorkflowDesign(
    workflow: definition,
    stages: [
      WorkflowStage(
        id: 'start-1',
        key: 'start',
        type: WorkflowStageType.start,
        title: 'شروع',
        sequence: 0,
        configurationComplete: false,
        config: {'trigger_type': 'Manual'},
      ),
    ],
    transitions: [],
  );

  @override
  Future<WorkflowDesign> getDesign(String definition) async => design;

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: [], modules: []);

  @override
  Future<WorkflowStage> saveStartSettings({
    required String definition,
    required String triggerType,
    required List<String> initiatorRoles,
    required String subjectSource,
    required String passMode,
  }) async =>
      throw StateError('Server unavailable');
}

void main() {
  test('failed start settings save retains the saved configuration', () async {
    final cubit = WorkflowDesignerCubit(
      repository: _FailingStartRepository(),
      definition: _FailingStartRepository.definition.id,
    );
    addTearDown(cubit.close);
    await cubit.load();

    final saved = await cubit.saveStart(
      triggerType: 'Document Event',
      initiatorRoles: const ['HR Manager'],
      subjectSource: 'Referenced Document',
      passMode: 'Direct',
    );

    expect(saved, isFalse);
    expect(cubit.state.status, WorkflowDesignerStatus.failure);
    expect(cubit.state.message, 'ذخیره تنظیمات شروع ممکن نشد.');
    expect(
      cubit.state.design!.stages.single.config['trigger_type'],
      'Manual',
    );
  });

  testWidgets('failed start settings save keeps page open and shows error',
      (tester) async {
    final cubit = WorkflowDesignerCubit(
      repository: _FailingStartRepository(),
      definition: _FailingStartRepository.definition.id,
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<WorkflowDesignerCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: StartSettingsPage(
            stage: _FailingStartRepository.design.stages.single,
            roles: const [],
          ),
        ),
      ),
    );
    await tester.tap(find.text('ذخیره تنظیمات شروع'));
    await tester.pumpAndSettle();

    expect(find.byType(StartSettingsPage), findsOneWidget);
    expect(cubit.state.status, WorkflowDesignerStatus.failure);
    expect(find.text('ذخیره تنظیمات شروع ممکن نشد.'), findsOneWidget);
  });
}
