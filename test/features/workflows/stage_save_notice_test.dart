import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_designer_cubit.dart';
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
  _Repo({this.notice});
  final String? notice;
  Map<String, dynamic>? savedConfig;
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
    savedConfig = config;
    return notice == null
        ? _design
        : WorkflowDesign(
            workflow: _design.workflow,
            stages: _design.stages,
            transitions: _design.transitions,
            notice: notice,
          );
  }
}

const _stage = WorkflowStage(
    id: 'S1',
    key: 'S1',
    type: WorkflowStageType.approval,
    title: 'تأیید',
    sequence: 2,
    configurationComplete: true,
    config: {});

void main() {
  test('a server notice on save is surfaced as the state message', () async {
    final repo = _Repo(notice: 'این مرحله تنظیم قدیمی «ویرایش محدود» دارد.');
    final cubit = WorkflowDesignerCubit(repository: repo, definition: 'WF');
    addTearDown(cubit.close);
    await cubit.load();
    final saved = await cubit.saveStage(_stage, {'title': 'تأیید'});
    expect(saved, isTrue);
    // The server's Persian notice replaces the plain confirmation so the
    // existing snackbar shows it.
    expect(cubit.state.message,
        'این مرحله تنظیم قدیمی «ویرایش محدود» دارد.');
  });

  test('without a server notice the plain confirmation is kept', () async {
    final repo = _Repo();
    final cubit = WorkflowDesignerCubit(repository: repo, definition: 'WF');
    addTearDown(cubit.close);
    await cubit.load();
    final saved = await cubit.saveStage(_stage, {'title': 'تأیید'});
    expect(saved, isTrue);
    expect(cubit.state.message, 'تنظیمات مرحله ذخیره شد.');
  });

  test('the repository parses a notice from the design payload', () async {
    final client = _DesignClient(notice: 'تنظیم قدیمی حفظ شد.');
    final repository = FrappeWorkflowRepository(client);
    final design = await repository.saveStageSettings(
        definition: 'WF', stage: 'S1', config: {'title': 'تأیید'});
    expect(design.notice, 'تنظیم قدیمی حفظ شد.');
  });

  test('the repository leaves notice null when the server sends none',
      () async {
    final client = _DesignClient();
    final repository = FrappeWorkflowRepository(client);
    final design = await repository.saveStageSettings(
        definition: 'WF', stage: 'S1', config: {'title': 'تأیید'});
    expect(design.notice, isNull);
  });
}

/// A client whose `save_stage_settings` answers with a design payload that
/// carries (or omits) a `notice` field, mirroring the backend contract.
class _DesignClient extends Fake implements FrappeApiClient {
  _DesignClient({this.notice});
  final String? notice;
  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    expect(method, 'asoud_erp.api.v1.workflow.save_stage_settings');
    return {
      'workflow': {
        'name': 'WF',
        'workflow_code': 'purchase',
        'workflow_title': 'درخواست خرید',
        'target_doctype': 'ASOUD Workflow Request',
        'status': 'Active',
        'version_no': 1,
        'steps_count': 1,
      },
      'stages': <Map<String, dynamic>>[],
      'transitions': <Map<String, dynamic>>[],
      if (notice != null) 'notice': notice,
    };
  }
}
