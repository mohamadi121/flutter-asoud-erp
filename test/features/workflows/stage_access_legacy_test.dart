import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_stage_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _design = WorkflowDesign(
  workflow: WorkflowDefinition(
      id: 'WF',
      code: 'purchase',
      title: 'درخواست خرید',
      targetDoctype: 'ASOUD Workflow Request',
      status: WorkflowDefinitionStatus.active,
      isLocked: false,
      version: 1,
      stepsCount: 1,
      modified: null),
  stages: [],
  transitions: [],
);

class _Repo extends Fake implements WorkflowRepository {
  final saved = <Map<String, dynamic>>[];
  @override
  Future<WorkflowDesign> getDesign(String definition) async => _design;
  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(companies: ['تابان'], modules: []);
  @override
  Future<WorkflowDesign> saveStageSettings(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config}) async {
    saved.add(config);
    return _design;
  }
}

WorkflowStage _stage(Map<String, dynamic> config) => WorkflowStage(
    id: 'S1',
    key: 'S1',
    type: WorkflowStageType.userTask,
    title: 'ثبت درخواست',
    sequence: 2,
    configurationComplete: true,
    config: config);

Future<_Repo> _open(
    WidgetTester tester, double width, WorkflowStage stage) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  final cubit = WorkflowDesignerCubit(repository: repo, definition: 'WF');
  addTearDown(cubit.close);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    builder: (_, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: BlocProvider.value(
        value: cubit,
        child: WorkflowStageSettingsPage(stage: stage, roles: const [])),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('fallback page offers no Limited Edit for a new stage ($width)',
        (tester) async {
      final repo = await _open(
          tester, width, _stage({'document_access': 'Read Only'}));
      // Only the two real options are offered; the legacy one is gone.
      expect(find.text('ویرایش محدود'), findsNothing);
      expect(find.text('فقط مشاهده'), findsOneWidget);
      expect(find.text('مشاهده و ویرایش'), findsOneWidget);
      // Picking an option sends the value and the changed flag.
      await tester.tap(find.text('مشاهده و ویرایش'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ذخیره مرحله'));
      await tester.pumpAndSettle();
      expect(repo.saved.single['document_access'], 'Edit');
      expect(repo.saved.single['document_access_changed'], isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fallback page keeps a legacy Limited Edit value ($width)',
        (tester) async {
      final repo = await _open(
          tester, width, _stage({'document_access': 'Limited Edit'}));
      // The legacy value is not offered and not converted: a notice explains
      // it stays until the user picks, and no segment is highlighted.
      expect(find.text('ویرایش محدود'), findsNothing);
      expect(find.text('این مرحله تنظیم قدیمی «ویرایش محدود» دارد و تا انتخاب شما تغییر نمی‌کند.'),
          findsOneWidget);
      // Saving without touching access sends the stored value back unchanged,
      // with no document_access_changed flag.
      await tester.tap(find.text('ذخیره مرحله'));
      await tester.pumpAndSettle();
      expect(repo.saved.single['document_access'], 'Limited Edit');
      expect(repo.saved.single.containsKey('document_access_changed'), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
