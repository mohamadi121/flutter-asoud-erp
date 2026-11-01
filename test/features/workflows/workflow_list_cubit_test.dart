import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements WorkflowRepository {
  int calls = 0;
  List<WorkflowDefinition> items = [sampleWorkflow];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) async =>
      throw UnimplementedError();
  String? receivedSearch;
  WorkflowDefinitionStatus? receivedStatus;

  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition,
          {String? beforeStage}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDesign> getDesign(String definition) =>
      throw UnimplementedError();

  @override
  Future<WorkflowStage> saveStartSettings(
          {required String definition,
          required String triggerType,
          required List<String> initiatorRoles,
          required String subjectSource,
          required String passMode}) =>
      throw UnimplementedError();

  @override
  Future<WorkflowDefinition> createDraft({
    required String title,
    required String moduleKey,
    required String targetDoctype,
    required String creationMode,
    String? description,
    String? company,
    String? iconKey,
    String? colorHex,
  }) async =>
      sampleWorkflow;

  @override
  Future<WorkflowFormOptions> getFormOptions() async =>
      const WorkflowFormOptions(
        companies: [],
        modules: [],
      );

  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async {
    calls++;
    receivedSearch = search;
    receivedStatus = status;
    return items;
  }
}

class _PreviewRepository extends _FakeRepository implements OfflinePreviewAware {
  @override
  bool get isOfflinePreview => true;
}

class _FailedRepository extends _FakeRepository {
  @override
  Future<List<WorkflowDefinition>> getWorkflows({String? search, WorkflowDefinitionStatus? status,
      String? company, String orderBy = 'modified desc'}) async {
    throw const ApiException(kind: ApiFailureKind.network, message: 'قطع ارتباط');
  }
}

const sampleWorkflow = WorkflowDefinition(
  id: 'WF-1404-001',
  code: 'WF-1404-001',
  title: 'فرایند خرید کالا',
  targetDoctype: 'Material Request',
  status: WorkflowDefinitionStatus.active,
  isLocked: false,
  version: 1,
  stepsCount: 4,
  modified: null,
);

void main() {
  test('confirmed deletion reloads authoritative list, not cached preview', () async {
    final preview = _PreviewRepository();
    final live = _FakeRepository()..items = [];
    final cubit = WorkflowListCubit(repository: preview);
    await cubit.load();
    expect(cubit.state.offlinePreview, isTrue);
    cubit.recordMutation(sampleWorkflow.id);
    await cubit.load(authoritativeRepository: live);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.offlinePreview, isFalse);
    expect(preview.calls, 1);
    expect(live.calls, 1);
    await cubit.close();
  });

  test('failed authoritative refresh preserves confirmed deletion without fallback', () async {
    final preview = _PreviewRepository();
    final cubit = WorkflowListCubit(repository: preview);
    await cubit.load();
    cubit.recordMutation(sampleWorkflow.id);
    await cubit.load(authoritativeRepository: _FailedRepository());
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.status, WorkflowListLoadStatus.failure);
    expect(preview.calls, 1);
    await cubit.close();
  });
  test('فهرست فرایندها را فقط از repository دریافت می‌کند', () async {
    final repository = _FakeRepository();
    final cubit = WorkflowListCubit(repository: repository);

    await cubit.load();

    expect(cubit.state.status, WorkflowListLoadStatus.success);
    expect(cubit.state.items, [sampleWorkflow]);
    await cubit.close();
  });

  test('فیلتر فعال به قرارداد repository منتقل می‌شود', () async {
    final repository = _FakeRepository();
    final cubit = WorkflowListCubit(repository: repository);

    await cubit.setFilter(WorkflowDefinitionStatus.active);

    expect(repository.receivedStatus, WorkflowDefinitionStatus.active);
    await cubit.close();
  });
}
