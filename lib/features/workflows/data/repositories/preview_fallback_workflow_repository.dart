import '../../../../core/network/api_exception.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';

class PreviewFallbackWorkflowRepository
    implements WorkflowRepository, OfflinePreviewAware {
  PreviewFallbackWorkflowRepository(this._remote);

  final WorkflowRepository _remote;
  final Map<String, WorkflowDesign> _designs = {};
  bool _offline = false;
  int _draftSequence = 1;

  @override
  bool get isOfflinePreview => _offline;

  static const _options = WorkflowFormOptions(
    companies: ['دفتر نمونه آفلاین'],
    roles: ['مدیر سیستم', 'مدیر حساب‌ها', 'مدیر خرید', 'کارشناس'],
    departments: [
      WorkflowTargetOption(id: 'حسابداری - آفلاین', label: 'واحد حسابداری'),
      WorkflowTargetOption(id: 'خرید - آفلاین', label: 'واحد خرید'),
    ],
    employees: [
      WorkflowTargetOption(
          id: 'HR-EMP-OFFLINE-001',
          label: 'احمد رضایی',
          department: 'واحد حسابداری'),
      WorkflowTargetOption(
          id: 'HR-EMP-OFFLINE-002',
          label: 'سارا محمدی',
          department: 'واحد خرید'),
    ],
    modules: [
      WorkflowModuleOption(key: 'Purchase', doctypes: [
        WorkflowDoctypeOption(name: 'Material Request', available: true),
        WorkflowDoctypeOption(name: 'Purchase Order', available: true),
      ]),
      WorkflowModuleOption(key: 'Accounting', doctypes: [
        WorkflowDoctypeOption(name: 'Payment Request', available: true),
        WorkflowDoctypeOption(name: 'Expense Claim', available: true),
        WorkflowDoctypeOption(name: 'Journal Entry', available: true),
      ]),
      WorkflowModuleOption(key: 'HR', doctypes: [
        WorkflowDoctypeOption(name: 'Leave Application', available: true),
        WorkflowDoctypeOption(name: 'Job Applicant', available: true),
      ]),
    ],
  );

  List<WorkflowDefinition> get _samples => const [
        WorkflowDefinition(
          id: 'PREVIEW-WF-001',
          code: 'WF-1404-001',
          title: 'فرایند خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
          iconKey: 'purchase',
        ),
        WorkflowDefinition(
          id: 'PREVIEW-WF-002',
          code: 'WF-1404-002',
          title: 'درخواست مرخصی',
          targetDoctype: 'Leave Application',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 5,
          modified: null,
          iconKey: 'leave',
        ),
        WorkflowDefinition(
          id: 'PREVIEW-WF-003',
          code: 'WF-1404-003',
          title: 'فرایند استخدام',
          targetDoctype: 'Job Applicant',
          status: WorkflowDefinitionStatus.inactive,
          isLocked: true,
          version: 1,
          stepsCount: 3,
          modified: null,
          iconKey: 'hiring',
          pendingReason: 'تنظیمات این فرایند کامل نشده است',
        ),
      ];

  bool _canPreview(Object error) =>
      error is ApiException &&
      (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout);

  Future<T> _remoteOrPreview<T>(
    Future<T> Function() remote,
    T Function() preview, {
    bool probe = false,
  }) async {
    if (_offline && !probe) return preview();
    try {
      final result = await remote();
      _offline = false;
      return result;
    } catch (error) {
      if (!_canPreview(error)) rethrow;
      _offline = true;
      return preview();
    }
  }

  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) =>
      _remoteOrPreview(
        () => _remote.getWorkflows(
            search: search, status: status, company: company, orderBy: orderBy),
        () {
          final all = [
            ..._samples,
            ..._designs.values.map((item) => item.workflow)
          ];
          final query = search?.trim().toLowerCase() ?? '';
          return all
              .where((item) =>
                  (status == null || item.status == status) &&
                  (query.isEmpty ||
                      item.title.toLowerCase().contains(query) ||
                      item.code.toLowerCase().contains(query)))
              .toList();
        },
        probe: true,
      );

  @override
  Future<WorkflowFormOptions> getFormOptions() =>
      _remoteOrPreview(_remote.getFormOptions, () => _options);

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
  }) =>
      _remoteOrPreview(
        () => _remote.createDraft(
            title: title,
            moduleKey: moduleKey,
            targetDoctype: targetDoctype,
            creationMode: creationMode,
            description: description,
            company: company,
            iconKey: iconKey,
            colorHex: colorHex),
        () {
          final sequence = _draftSequence++;
          final id = 'PREVIEW-DRAFT-$sequence';
          final workflow = WorkflowDefinition(
            id: id,
            code: 'PREVIEW-$sequence',
            title: title,
            targetDoctype: targetDoctype,
            status: WorkflowDefinitionStatus.inactive,
            isLocked: true,
            version: 1,
            stepsCount: 1,
            modified: DateTime.now(),
            company: company,
            description: description,
            moduleKey: moduleKey,
            creationMode: creationMode,
            pendingReason: 'پیش‌نمایش آفلاین؛ در ERPNext ذخیره نشده است',
            iconKey: iconKey,
            colorHex: colorHex,
          );
          final start = WorkflowStage(
            id: '$id-START',
            key: 'START',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 1,
            configurationComplete: false,
          );
          _designs[id] = WorkflowDesign(
              workflow: workflow, stages: [start], transitions: const []);
          return workflow;
        },
      );

  @override
  Future<WorkflowDesign> getDesign(String definition) => _remoteOrPreview(
      () => _remote.getDesign(definition),
      () => _designs[definition] ?? _sampleDesign(definition));

  WorkflowDesign _sampleDesign(String id) {
    final workflow = _samples.firstWhere((item) => item.id == id,
        orElse: () => _samples.first);
    final start = WorkflowStage(
        id: '${workflow.id}-START',
        key: 'START',
        type: WorkflowStageType.start,
        title: 'شروع',
        sequence: 1,
        configurationComplete: true,
        config: const {'trigger_type': 'Manual'});
    return WorkflowDesign(
        workflow: workflow, stages: [start], transitions: const []);
  }

  @override
  Future<WorkflowDesign> addStage(
          {required String definition,
          required String afterStage,
          required WorkflowStageType type}) =>
      _remoteOrPreview(
        () => _remote.addStage(
            definition: definition, afterStage: afterStage, type: type),
        () {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final sequence = design.stages.length + 1;
          final stage = WorkflowStage(
            id: '$definition-STAGE-$sequence',
            key: 'STAGE_$sequence',
            type: type,
            title: _stageTitle(type),
            sequence: sequence,
            configurationComplete: false,
          );
          final transition = WorkflowTransition(
            id: '$definition-TRANSITION-$sequence',
            fromStage: afterStage,
            toStage: stage.id,
          );
          final updated = WorkflowDesign(
              workflow: design.workflow,
              stages: [...design.stages, stage],
              transitions: [...design.transitions, transition]);
          _designs[definition] = updated;
          return updated;
        },
      );

  @override
  Future<WorkflowStage> saveStartSettings(
          {required String definition,
          required String triggerType,
          required List<String> initiatorRoles,
          required String subjectSource,
          required String passMode}) =>
      _remoteOrPreview(
        () => _remote.saveStartSettings(
            definition: definition,
            triggerType: triggerType,
            initiatorRoles: initiatorRoles,
            subjectSource: subjectSource,
            passMode: passMode),
        () {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final old = design.stages.first;
          final updated = WorkflowStage(
              id: old.id,
              key: old.key,
              type: old.type,
              title: old.title,
              sequence: old.sequence,
              configurationComplete: true,
              config: {
                'trigger_type': triggerType,
                'initiator_roles': initiatorRoles,
                'subject_source': subjectSource,
                'pass_mode': passMode
              });
          _designs[definition] = WorkflowDesign(
              workflow: design.workflow,
              stages: [updated, ...design.stages.skip(1)],
              transitions: design.transitions);
          return updated;
        },
      );

  @override
  Future<List<WorkflowFieldOption>> getConditionFields(String definition) =>
      _remoteOrPreview(
          () => _remote.getConditionFields(definition),
          () => const [
                WorkflowFieldOption(
                    name: 'status', label: 'وضعیت', type: 'Select'),
                WorkflowFieldOption(
                    name: 'owner', label: 'ایجادکننده', type: 'Link'),
                WorkflowFieldOption(
                    name: 'grand_total', label: 'مبلغ کل', type: 'Currency'),
              ]);

  @override
  Future<WorkflowDesign> saveStageSettings(
          {required String definition,
          required String stage,
          required Map<String, dynamic> config}) =>
      _remoteOrPreview(
        () => _remote.saveStageSettings(
            definition: definition, stage: stage, config: config),
        () {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final stages = design.stages
              .map((item) => item.id == stage
                  ? WorkflowStage(
                      id: item.id,
                      key: item.key,
                      type: item.type,
                      title: config['title']?.toString() ?? item.title,
                      sequence: item.sequence,
                      configurationComplete: true,
                      subtype: item.subtype,
                      config: config)
                  : item)
              .toList();
          final updated = WorkflowDesign(
              workflow: design.workflow,
              stages: stages,
              transitions: design.transitions);
          _designs[definition] = updated;
          return updated;
        },
      );
}

String _stageTitle(WorkflowStageType type) => switch (type) {
      WorkflowStageType.start => 'شروع',
      WorkflowStageType.userTask => 'فرم و دریافت اطلاعات',
      WorkflowStageType.approval => 'تأیید یا رد',
      WorkflowStageType.condition => 'شرط و مسیر',
      WorkflowStageType.systemAction => 'عملیات سیستمی',
      WorkflowStageType.wait => 'انتظار و زمان‌بندی',
      WorkflowStageType.end => 'پایان فرایند',
    };
