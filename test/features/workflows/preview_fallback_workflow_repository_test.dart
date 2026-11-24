import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_fallback_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailableRepository implements WorkflowRepository {
  _UnavailableRepository([this.kind = ApiFailureKind.network]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) async =>
      unavailable;
  final ApiFailureKind kind;

  Never get unavailable => throw ApiException(message: 'offline', kind: kind);

  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) async =>
      unavailable;
  @override
  Future<WorkflowDefinition> createDraft(
          {required String title,
          required String moduleKey,
          required String targetDoctype,
          required String creationMode,
          String? description,
          String? company,
          String? iconKey,
          String? colorHex}) async =>
      unavailable;
  @override
  Future<List<WorkflowFieldOption>> getConditionFields(
    String definition, {
    String? beforeStage,
  }) async =>
      unavailable;
  @override
  Future<WorkflowDesign> getDesign(String definition) async => unavailable;
  @override
  Future<WorkflowFormOptions> getFormOptions() async => unavailable;
  @override
  Future<List<WorkflowDefinition>> getWorkflows(
          {String? search,
          WorkflowDefinitionStatus? status,
          String? company,
          String orderBy = 'modified desc'}) async =>
      unavailable;
  @override
  Future<WorkflowStage> saveStartSettings(
          {required String definition,
          required String triggerType,
          required List<String> initiatorRoles,
          required String subjectSource,
          required String passMode}) async =>
      unavailable;
  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) async =>
      unavailable;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('در خطای شبکه فهرست پیش‌نمایش را با برچسب آفلاین برمی‌گرداند', () async {
    final repository =
        PreviewFallbackWorkflowRepository(_UnavailableRepository());

    final items = await repository.getWorkflows();

    expect(repository.isOfflinePreview, isTrue);
    expect(items, isNotEmpty);
    expect(items.first.id, startsWith('PREVIEW-'));
  });

  test('پیش‌نویس و مرحله آفلاین فقط در حافظه ساخته می‌شوند', () async {
    final repository =
        PreviewFallbackWorkflowRepository(_UnavailableRepository());
    await repository.getFormOptions();

    final draft = await repository.createDraft(
        title: 'فرایند آزمایشی',
        moduleKey: 'Purchase',
        targetDoctype: 'Material Request',
        creationMode: 'Custom');
    final design = await repository.getDesign(draft.id);
    final updated = await repository.addStage(
        definition: draft.id,
        afterStage: design.stages.first.id,
        type: WorkflowStageType.approval);

    expect(draft.pendingReason, contains('ASOUD ERP'));
    expect(updated.stages, hasLength(2));
    expect(updated.transitions, hasLength(1));
  });

  test('خطای اعتبارسنجی Backend به پیش‌نمایش تبدیل نمی‌شود', () async {
    final repository = PreviewFallbackWorkflowRepository(
        _UnavailableRepository(ApiFailureKind.validation));

    await expectLater(
        repository.getFormOptions(), throwsA(isA<ApiException>()));
    expect(repository.isOfflinePreview, isFalse);
  });

  group('قوانین اتصال مسیرها در پیش‌نمایش آفلاین', () {
    late PreviewFallbackWorkflowRepository repository;
    late String definition;
    late String startId;
    late String taskId;
    late String conditionId;
    late String endId;

    setUp(() async {
      repository = PreviewFallbackWorkflowRepository(_UnavailableRepository());
      final draft = await repository.createDraft(
          title: 'فرایند آزمایشی',
          moduleKey: 'Purchase',
          targetDoctype: 'Material Request',
          creationMode: 'Custom');
      definition = draft.id;
      var design = await repository.getDesign(definition);
      startId = design.stages.first.id;
      design = await repository.addStage(
          definition: definition,
          afterStage: startId,
          type: WorkflowStageType.userTask);
      taskId = design.stages.last.id;
      design = await repository.addStage(
          definition: definition,
          afterStage: taskId,
          type: WorkflowStageType.condition);
      conditionId = design.stages.last.id;
      design = await repository.addStage(
          definition: definition,
          afterStage: conditionId,
          type: WorkflowStageType.end);
      endId = design.stages.last.id;
    });

    test('اتصال از مرحلهٔ پایان رد می‌شود', () async {
      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: endId,
              toStage: taskId,
              action: 'ادامه'),
          throwsA(isA<StateError>().having(
              (error) => error.message, 'message', contains('مرحلهٔ پایان'))));
    });

    test('اتصال از شرط بدون نتیجهٔ بولی رد می‌شود', () async {
      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: conditionId,
              toStage: endId,
              action: 'ادامه',
              condition: const {}),
          throwsA(isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('خروجی شرط باید برقرار یا برقرار نیست'))));
    });

    test('اتصال به مرحلهٔ شروع از هر مرحله‌ای رد می‌شود', () async {
      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: taskId,
              toStage: startId,
              action: 'ادامه'),
          throwsA(isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('مسیر نمی‌تواند به مرحلهٔ شروع برگردد'))));
      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: conditionId,
              toStage: startId,
              action: 'ادامه',
              condition: const {'result': true}),
          throwsA(isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('مسیر نمی‌تواند به مرحلهٔ شروع برگردد'))));
    });

    test('مسیر تکراری با همان عمل از یک مرحله رد می‌شود', () async {
      final first = await repository.connectStages(
          definition: definition,
          fromStage: taskId,
          toStage: conditionId,
          action: 'تأیید');
      expect(first.transitions, hasLength(4));

      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: taskId,
              toStage: endId,
              action: 'تأیید'),
          throwsA(isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('این عمل از مرحلهٔ انتخاب‌شده از پیش مسیری دارد'))));
    });

    test('اتصال مرحله به خودش رد می‌شود', () async {
      await expectLater(
          repository.connectStages(
              definition: definition,
              fromStage: taskId,
              toStage: taskId,
              action: 'ادامه'),
          throwsA(isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('مسیر (ترنزیشن) گردش‌کار نامعتبر است'))));
    });

    test('اتصال معتبر مسیر جدید می‌سازد', () async {
      final updated = await repository.connectStages(
          definition: definition,
          fromStage: taskId,
          toStage: endId,
          action: 'تأیید');

      expect(updated.transitions, hasLength(4));
      final edge = updated.transitions.last;
      expect(edge.fromStage, taskId);
      expect(edge.toStage, endId);
      expect(edge.label, 'تأیید');
    });
  });
}
