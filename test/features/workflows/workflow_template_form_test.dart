import 'package:asoud_erp/features/workflows/data/workflow_template_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = WorkflowTemplate(id: 'system-leave', title: 'درخواست مرخصی',
    modified: '2026-01-01 10:20:30.123456', module: 'HR', targetDoctype: 'ASOUD Workflow Request',
    description: 'شرح الگو', icon: 'leave', color: '#6C3FF5', steps: 3);

class _Workflows extends Fake implements WorkflowRepository {
  bool createdCustom = false;
  @override
  Future<WorkflowFormOptions> getFormOptions() async => const WorkflowFormOptions(
      companies: ['دفتر نمونه'], modules: [WorkflowModuleOption(key: 'HR', doctypes: [])]);
  @override
  Future<WorkflowDefinition> createDraft({required String title, required String moduleKey,
      required String targetDoctype, required String creationMode, String? description,
      String? company, String? iconKey, String? colorHex}) async {
    createdCustom = true;
    throw StateError('Template mode must never call createDraft');
  }
}

class _Templates extends Fake implements WorkflowTemplateRepository {
  Map<String, Object>? copied;
  @override
  Future<WorkflowDefinition> copy({required String company, required WorkflowTemplate source,
      required String title, required String description, required String icon, required String color}) async {
    copied = {'company': company, 'source': source.id, 'modified': source.modified, 'title': title,
      'description': description, 'icon': icon, 'color': color};
    return WorkflowDefinition(id: 'independent-copy', code: 'WF-test', title: title,
        targetDoctype: source.targetDoctype, status: WorkflowDefinitionStatus.inactive,
        isLocked: true, version: 1, stepsCount: 3, modified: null);
  }
}

void main() {
  test('template creates an independent draft through its feature repository', () async {
    final workflows = _Workflows();
    final templates = _Templates();
    final cubit = WorkflowFormCubit(repository: workflows, templates: templates);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.selectTemplate(_source);
    expect(cubit.state.title, _source.title);
    expect(cubit.state.targetDoctype, _source.targetDoctype);
    cubit.changeTitle('مرخصی واحد فروش');
    await cubit.submit();
    expect(workflows.createdCustom, isFalse);
    expect(templates.copied!['source'], _source.id);
    expect(templates.copied!['modified'], _source.modified);
    expect(templates.copied!['title'], 'مرخصی واحد فروش');
    expect(cubit.state.createdDraft!.id, isNot(_source.id));
    expect(cubit.state.createdDraft!.isSystemTemplate, isFalse);
  });

  test('template changes preserve typed metadata and custom mode clears the source', () async {
    final cubit = WorkflowFormCubit(repository: _Workflows(), templates: _Templates());
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('عنوان شخصی');
    cubit.changeDescription('توضیح شخصی');
    cubit.selectTemplate(_source);
    expect(cubit.state.title, 'عنوان شخصی');
    expect(cubit.state.description, 'توضیح شخصی');
    cubit.changeCreationMode('Custom');
    expect(cubit.state.selectedTemplate, isNull);
    expect(cubit.state.title, 'عنوان شخصی');
  });

  test('template mode without selected source cannot silently create a blank workflow', () async {
    final repository = _Workflows();
    final cubit = WorkflowFormCubit(repository: repository, templates: _Templates());
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeTitle('گردش نمونه');
    cubit.changeCreationMode('Template');
    await cubit.submit();
    expect(repository.createdCustom, isFalse);
    expect(cubit.state.message, 'ابتدا یک الگوی آماده را انتخاب کنید.');
  });

  test('changing office invalidates a previously selected template', () async {
    final cubit = WorkflowFormCubit(repository: _Workflows(), templates: _Templates());
    addTearDown(cubit.close);
    await cubit.load();
    cubit.selectTemplate(_source);
    cubit.changeCompany('دفتر دیگر');
    expect(cubit.state.selectedTemplate, isNull);
    await cubit.submit();
    expect(cubit.state.message, 'ابتدا یک الگوی آماده را انتخاب کنید.');
  });
}
