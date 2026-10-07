import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/request_types/domain/request_templates.dart';
import 'package:asoud_erp/features/request_types/presentation/cubit/request_type_builder_cubit.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every server call fails as offline, so the preview repository answers.
class _OfflineRemote implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
      const ApiException(message: 'offline', kind: ApiFailureKind.network));
}

WorkflowStage _formStage(WorkflowDesign design) {
  final start = design.stages
      .firstWhere((stage) => stage.type == WorkflowStageType.start);
  final edge = design.transitions.firstWhere((e) => e.fromStage == start.id);
  return design.stages.firstWhere((stage) => stage.id == edge.toStage);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the builder suggests mission and advance only', () {
    // `leave` and `purchase` are system templates of the server
    // (`template_key`); a custom copy would duplicate them.
    expect(requestTemplates.map((template) => template.key),
        ['mission', 'advance']);
    expect(requestTemplates.map((template) => template.info.title),
        ['درخواست مأموریت', 'درخواست مساعده']);
  });

  test('builds and persists a three-step form without changing access',
      () async {
    final repository = PreviewFallbackWorkflowRepository(_OfflineRemote());
    final cubit =
        RequestTypeBuilderCubit(repository: repository, company: 'دفتر نمونه');
    await cubit.load();
    expect(cubit.state.roles, isEmpty);

    cubit.updateInfo(const RequestTypeInfo(
        title: 'درخواست خرید',
        shortTitle: 'خرید کالا و خدمات',
        category: 'Purchase'));
    await cubit.saveInfo();
    expect(cubit.state.step, 1);
    final definition = cubit.state.definition!;
    expect(definition.targetDoctype, requestTargetDoctype);
    expect(definition.shortTitle, 'خرید کالا و خدمات');
    expect(definition.category, 'Purchase');

    cubit.setFields(const [
      WorkflowFormFieldDefinition(
          key: 'purchase_type',
          label: 'نوع خرید',
          type: 'Choice',
          required: true,
          options: ['کالا', 'خدمت'],
          defaultValue: 'کالا'),
    ]);
    await cubit.saveForm();
    expect(cubit.state.step, 2);
    var design = await repository.getDesign(definition.id);
    final form = _formStage(design);
    expect(form.type, WorkflowStageType.userTask);
    expect(form.config['assignment_type'], 'Initiator');
    final fields = form.config['form_fields'] as List;
    expect(fields.single['key'], 'purchase_type');
    expect(fields.single['default_value'], 'کالا');

    // Saving the form again updates the same stage.
    cubit.back();
    await cubit.saveForm();
    design = await repository.getDesign(definition.id);
    expect(design.stages, hasLength(2));

    final previousAccess = design.stages.first.config['initiator_roles'];
    cubit.moveField('purchase_type', 'base:number');
    cubit.resizeField('purchase_type');
    await cubit.finish();
    expect(cubit.state.completed, isTrue);
    design = await repository.getDesign(definition.id);
    expect(design.stages.first.config['initiator_roles'], previousAccess);
    expect((_formStage(design).config['form_layout'] as List).first,
        {'key': 'purchase_type', 'span': 2});

    final edit = RequestTypeBuilderCubit(
        repository: repository, existing: design.workflow);
    await edit.load();
    expect(edit.state.info.title, 'درخواست خرید');
    expect(edit.state.info.shortTitle, 'خرید کالا و خدمات');
    expect(edit.state.fields.single.options, ['کالا', 'خدمت']);
    expect(edit.layout.first.key, 'purchase_type');
    expect(edit.layout.first.fullWidth, isTrue);
    expect(edit.state.active, isFalse);
  });

  test('does not create a draft for a short title', () async {
    final repository = PreviewFallbackWorkflowRepository(_OfflineRemote());
    final cubit = RequestTypeBuilderCubit(repository: repository);
    cubit.updateInfo(const RequestTypeInfo(title: 'خر'));
    await cubit.saveInfo();
    expect(cubit.state.step, 0);
    expect(cubit.state.definition, isNull);
    expect(cubit.state.message, isNotNull);
  });
}
