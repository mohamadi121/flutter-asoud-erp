import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  bool _loaded = false;
  Future<void> _persistTail = Future<void>.value();
  static const _storageKey = 'asoud_workflow_designs_v2';

  Future<void> _loadLocal() async {
    if (_loaded) return;
    _loaded = true;
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final design = _designFromMap(Map<String, dynamic>.from(item));
        _designs[design.workflow.id] = design;
      }
      _draftSequence = _designs.length + 1;
    } catch (_) {
      // A corrupt preview must never block the real server flow.
    }
  }

  Future<void> _persist() {
    final snapshot =
        jsonEncode(_designs.values.map(_designToMap).toList(growable: false));
    final write = _persistTail.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_storageKey, snapshot)) {
        throw StateError('ذخیره گردش کار روی دستگاه انجام نشد.');
      }
    });
    _persistTail = write.catchError((Object _) {});
    return write;
  }

  Map<String, dynamic> _designToMap(WorkflowDesign design) => {
        'workflow': {
          'id': design.workflow.id,
          'code': design.workflow.code,
          'title': design.workflow.title,
          'target_doctype': design.workflow.targetDoctype,
          'company': design.workflow.company,
          'description': design.workflow.description,
          'module_key': design.workflow.moduleKey,
          'creation_mode': design.workflow.creationMode,
          'icon_key': design.workflow.iconKey,
          'color_hex': design.workflow.colorHex,
          'short_title': design.workflow.shortTitle,
          'category': design.workflow.category,
          'show_in_list': design.workflow.showInList,
          'user_submittable': design.workflow.userSubmittable,
        },
        'stages': design.stages
            .map((stage) => {
                  'id': stage.id,
                  'key': stage.key,
                  'type': stage.type.name,
                  'title': stage.title,
                  'sequence': stage.sequence,
                  'complete': stage.configurationComplete,
                  'config': stage.config,
                  'x': stage.positionX,
                  'y': stage.positionY,
                })
            .toList(growable: false),
        'transitions': design.transitions
            .map((edge) => {
                  'id': edge.id,
                  'from': edge.fromStage,
                  'to': edge.toStage,
                  'label': edge.label,
                  'condition': edge.condition,
                })
            .toList(growable: false),
      };

  WorkflowDesign _designFromMap(Map<String, dynamic> raw) {
    final workflow = Map<String, dynamic>.from(raw['workflow'] as Map);
    final stages =
        (raw['stages'] as List? ?? const []).whereType<Map>().map((value) {
      final item = Map<String, dynamic>.from(value);
      return WorkflowStage(
        id: item['id']?.toString() ?? '',
        key: item['key']?.toString() ?? '',
        type: WorkflowStageType.values.firstWhere(
          (type) => type.name == item['type'],
          orElse: () => WorkflowStageType.userTask,
        ),
        title: item['title']?.toString() ?? '',
        sequence: int.tryParse(item['sequence']?.toString() ?? '') ?? 0,
        configurationComplete: item['complete'] == true,
        config: item['config'] is Map
            ? Map<String, dynamic>.from(item['config'] as Map)
            : const {},
        positionX: (item['x'] as num?)?.toDouble() ?? 0,
        positionY: (item['y'] as num?)?.toDouble() ?? 0,
      );
    }).toList(growable: false);
    final transitions =
        (raw['transitions'] as List? ?? const []).whereType<Map>().map((value) {
      final item = Map<String, dynamic>.from(value);
      return WorkflowTransition(
        id: item['id']?.toString() ?? '',
        fromStage: item['from']?.toString() ?? '',
        toStage: item['to']?.toString() ?? '',
        label: item['label']?.toString(),
        condition: item['condition'] is Map
            ? Map<String, dynamic>.from(item['condition'] as Map)
            : const {},
      );
    }).toList(growable: false);
    return WorkflowDesign(
      workflow: WorkflowDefinition(
        id: workflow['id']?.toString() ?? '',
        code: workflow['code']?.toString() ?? '',
        title: workflow['title']?.toString() ?? '',
        targetDoctype: workflow['target_doctype']?.toString() ?? '',
        status: WorkflowDefinitionStatus.inactive,
        isLocked: true,
        version: 1,
        stepsCount: stages.length,
        modified: null,
        company: workflow['company']?.toString(),
        description: workflow['description']?.toString(),
        moduleKey: workflow['module_key']?.toString(),
        creationMode: workflow['creation_mode']?.toString(),
        pendingReason: 'ذخیره محلی؛ در انتظار همگام‌سازی با ASOUD ERP',
        iconKey: workflow['icon_key']?.toString(),
        colorHex: workflow['color_hex']?.toString(),
        shortTitle: workflow['short_title']?.toString(),
        category: workflow['category']?.toString(),
        showInList: workflow['show_in_list'] != false,
        userSubmittable: workflow['user_submittable'] != false,
      ),
      stages: stages,
      transitions: transitions,
    );
  }

  Future<void> _remember(String definition, WorkflowDesign design) async {
    _designs[definition] = design;
    await _persist();
  }

  Future<WorkflowDesign> _rememberRemoteDesign(
    String definition,
    Future<WorkflowDesign> Function() load,
  ) async {
    final design = await load();
    await _remember(definition, design);
    return design;
  }

  Future<WorkflowDefinition> _rememberRemoteWorkflow(
    String definition,
    Future<WorkflowDefinition> Function() load,
  ) async {
    final workflow = await load();
    final design = _designs[definition];
    if (design != null) {
      await _remember(
        definition,
        WorkflowDesign(
          workflow: workflow,
          stages: design.stages,
          transitions: design.transitions,
        ),
      );
    }
    return workflow;
  }

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
          stepsCount: 1,
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
          stepsCount: 1,
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
          stepsCount: 1,
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
    FutureOr<T> Function() preview, {
    bool probe = false,
  }) async {
    await _loadLocal();
    if (_offline && !probe) return await preview();
    try {
      final result = await remote();
      _offline = false;
      return result;
    } catch (error) {
      if (!_canPreview(error)) rethrow;
      _offline = true;
      return await preview();
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
        () async {
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
  Future<WorkflowDefinition> saveRequestTypeInfo({
    required String definition,
    required RequestTypeInfo info,
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteWorkflow(
          definition,
          () => _remote.saveRequestTypeInfo(definition: definition, info: info),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final old = design.workflow;
          final workflow = WorkflowDefinition(
            id: old.id,
            code: old.code,
            title: info.title,
            targetDoctype: old.targetDoctype,
            status: old.status,
            isLocked: old.isLocked,
            version: old.version,
            stepsCount: old.stepsCount,
            modified: DateTime.now(),
            company: old.company,
            description: info.description,
            moduleKey: info.moduleKey ?? old.moduleKey,
            creationMode: old.creationMode,
            frappeWorkflow: old.frappeWorkflow,
            pendingReason: old.pendingReason,
            missingRequirements: old.missingRequirements,
            iconKey: info.iconKey,
            colorHex: info.colorHex,
            shortTitle: info.shortTitle,
            category: info.category,
            showInList: info.showInList,
            userSubmittable: info.userSubmittable,
          );
          await _remember(
              definition,
              WorkflowDesign(
                  workflow: workflow,
                  stages: design.stages,
                  transitions: design.transitions));
          return workflow;
        },
      );

  @override
  Future<WorkflowDefinition> setWorkflowStatus({
    required String definition,
    required WorkflowDefinitionStatus status,
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteWorkflow(
          definition,
          () =>
              _remote.setWorkflowStatus(definition: definition, status: status),
        ),
        () => throw StateError('تغییر وضعیت در پیش‌نمایش آفلاین ممکن نیست.'),
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
        () async {
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
            pendingReason: 'پیش‌نمایش آفلاین؛ در ASOUD ERP همگام نشده است',
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
            positionX: 180,
            positionY: 60,
          );
          await _remember(
            id,
            WorkflowDesign(
              workflow: workflow,
              stages: [start],
              transitions: const [],
            ),
          );
          return workflow;
        },
      );

  @override
  Future<WorkflowDesign> getDesign(String definition) => _remoteOrPreview(
      () => _rememberRemoteDesign(
          definition, () => _remote.getDesign(definition)),
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
        positionX: 180,
        positionY: 60,
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
        () => _rememberRemoteDesign(
          definition,
          () => _remote.addStage(
              definition: definition, afterStage: afterStage, type: type),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final sequence = design.stages.length + 1;
          final stage = WorkflowStage(
            id: '$definition-STAGE-$sequence',
            key: 'STAGE_$sequence',
            type: type,
            title: _stageTitle(type),
            sequence: sequence,
            configurationComplete: false,
            positionX: design.stages.last.positionX,
            positionY: design.stages.last.positionY + 190,
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
          await _remember(definition, updated);
          return updated;
        },
      );

  @override
  Future<WorkflowDesign> insertStage({
    required String definition,
    required String transition,
    required WorkflowStageType type,
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteDesign(
          definition,
          () => _remote.insertStage(
            definition: definition,
            transition: transition,
            type: type,
          ),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final edge =
              design.transitions.firstWhere((item) => item.id == transition);
          final from =
              design.stages.firstWhere((item) => item.id == edge.fromStage);
          final to =
              design.stages.firstWhere((item) => item.id == edge.toStage);
          final sequence = design.stages.length + 1;
          final stage = WorkflowStage(
            id: '$definition-INSERT-$sequence',
            key: 'INSERT_$sequence',
            type: type,
            title: _stageTitle(type),
            sequence: sequence,
            configurationComplete: type == WorkflowStageType.end,
            positionX: (from.positionX + to.positionX) / 2,
            positionY: (from.positionY + to.positionY) / 2,
          );
          final updated = WorkflowDesign(
            workflow: design.workflow,
            stages: [...design.stages, stage],
            transitions: [
              ...design.transitions.where((item) => item.id != transition),
              WorkflowTransition(
                id: '$transition-A',
                fromStage: edge.fromStage,
                toStage: stage.id,
                label: edge.label,
                condition: edge.condition,
              ),
              WorkflowTransition(
                id: '$transition-B',
                fromStage: stage.id,
                toStage: edge.toStage,
                label: 'ادامه',
              ),
            ],
          );
          await _remember(definition, updated);
          return updated;
        },
      );

  @override
  Future<WorkflowDesign> connectStages({
    required String definition,
    required String fromStage,
    required String toStage,
    required String action,
    Map<String, dynamic> condition = const {},
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteDesign(
          definition,
          () => _remote.connectStages(
            definition: definition,
            fromStage: fromStage,
            toStage: toStage,
            action: action,
            condition: condition,
          ),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          if (fromStage == toStage) {
            throw StateError('Self transition is invalid');
          }
          final id = '$definition-EDGE-${design.transitions.length + 1}';
          final updated = WorkflowDesign(
            workflow: design.workflow,
            stages: design.stages,
            transitions: [
              ...design.transitions,
              WorkflowTransition(
                id: id,
                fromStage: fromStage,
                toStage: toStage,
                label: action,
                condition: condition,
              ),
            ],
          );
          await _remember(definition, updated);
          return updated;
        },
      );

  @override
  Future<WorkflowDesign> updateStagePositions({
    required String definition,
    required Map<String, ({double x, double y})> positions,
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteDesign(
          definition,
          () => _remote.updateStagePositions(
            definition: definition,
            positions: positions,
          ),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          final updated = WorkflowDesign(
            workflow: design.workflow,
            stages: design.stages.map((stage) {
              final point = positions[stage.id];
              return point == null
                  ? stage
                  : stage.copyWith(positionX: point.x, positionY: point.y);
            }).toList(growable: false),
            transitions: design.transitions,
          );
          await _remember(definition, updated);
          return updated;
        },
      );

  @override
  Future<WorkflowDesign> addConditionBranch({
    required String definition,
    required String conditionStage,
    required WorkflowStageType type,
    required bool result,
  }) =>
      _remoteOrPreview(
        () => _rememberRemoteDesign(
          definition,
          () => _remote.addConditionBranch(
            definition: definition,
            conditionStage: conditionStage,
            type: type,
            result: result,
          ),
        ),
        () async {
          final design = _designs[definition] ?? _sampleDesign(definition);
          if (design.transitions.any((item) =>
              item.fromStage == conditionStage &&
              item.condition['result'] == result)) {
            throw StateError('Offline condition branch already exists');
          }
          final sequence = design.stages.length + 1;
          final stage = WorkflowStage(
            id: '$definition-BRANCH-$sequence',
            key: 'BRANCH_$sequence',
            type: type,
            title: _stageTitle(type),
            sequence: sequence,
            configurationComplete: type == WorkflowStageType.end,
          );
          final transition = WorkflowTransition(
            id: '$definition-BRANCH-TRANSITION-$sequence',
            fromStage: conditionStage,
            toStage: stage.id,
            label: result ? 'بله' : 'خیر',
            condition: {'result': result},
          );
          final updated = WorkflowDesign(
            workflow: design.workflow,
            stages: [...design.stages, stage],
            transitions: [...design.transitions, transition],
          );
          await _remember(definition, updated);
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
        () async {
          final updated = await _remote.saveStartSettings(
              definition: definition,
              triggerType: triggerType,
              initiatorRoles: initiatorRoles,
              subjectSource: subjectSource,
              passMode: passMode);
          final design = _designs[definition];
          if (design != null) {
            await _remember(
              definition,
              WorkflowDesign(
                workflow: design.workflow,
                stages: [
                  for (final stage in design.stages)
                    if (stage.id == updated.id) updated else stage,
                ],
                transitions: design.transitions,
              ),
            );
          }
          return updated;
        },
        () async {
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
          await _remember(
              definition,
              WorkflowDesign(
                  workflow: design.workflow,
                  stages: [updated, ...design.stages.skip(1)],
                  transitions: design.transitions));
          return updated;
        },
      );

  @override
  Future<List<WorkflowFieldOption>> getConditionFields(
    String definition, {
    String? beforeStage,
  }) =>
      _remoteOrPreview(
          () =>
              _remote.getConditionFields(definition, beforeStage: beforeStage),
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
        () => _rememberRemoteDesign(
          definition,
          () => _remote.saveStageSettings(
              definition: definition, stage: stage, config: config),
        ),
        () async {
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
          await _remember(definition, updated);
          return updated;
        },
      );

  /// The offline counterpart of `workflow.save_stage_routes`: sets a stage's
  /// exits by decision on the local design (an empty target removes one).
  Future<WorkflowDesign> saveStageRoutesLocally({
    required String definition,
    required String stage,
    required Map<String, String> routes,
  }) async {
    await _loadLocal();
    final design = _designs[definition] ?? _sampleDesign(definition);
    final source = design.stages.firstWhere((item) => item.id == stage);
    final main = switch (source.type) {
      WorkflowStageType.approval => 'Approve',
      WorkflowStageType.systemAction => 'Success',
      _ => 'Complete',
    };
    String actionOf(WorkflowTransition edge) {
      final action = edge.condition['action']?.toString() ?? '';
      if (action.isNotEmpty) return action;
      return _routeLabels.entries
              .where((entry) => entry.value == edge.label)
              .map((entry) => entry.key)
              .firstOrNull ??
          '';
    }

    final transitions = [
      for (final edge in design.transitions)
        if (edge.fromStage != stage ||
            !routes.keys.any((action) =>
                actionOf(edge) == action ||
                (action == main && actionOf(edge).isEmpty)))
          edge,
    ];
    for (final entry in routes.entries) {
      if (entry.value.isEmpty) continue;
      transitions.add(WorkflowTransition(
        id: '$definition-EDGE-$stage-${entry.key}',
        fromStage: stage,
        toStage: entry.value,
        label: _routeLabels[entry.key],
        condition: {'action': entry.key},
      ));
    }
    final updated = WorkflowDesign(
        workflow: design.workflow,
        stages: design.stages,
        transitions: transitions);
    await _remember(definition, updated);
    return updated;
  }
}

const _routeLabels = {
  'Approve': 'تأیید',
  'Reject': 'رد',
  'Return': 'بازگشت برای اصلاح',
  'Complete': 'ادامه',
  'Success': 'موفقیت',
  'Error': 'خطا',
};

String _stageTitle(WorkflowStageType type) => switch (type) {
      WorkflowStageType.start => 'شروع',
      WorkflowStageType.userTask => 'فرم و دریافت اطلاعات',
      WorkflowStageType.approval => 'تأیید یا رد',
      WorkflowStageType.condition => 'شرط و مسیر',
      WorkflowStageType.systemAction => 'عملیات سیستمی',
      WorkflowStageType.wait => 'انتظار و زمان‌بندی',
      WorkflowStageType.end => 'پایان فرایند',
    };
