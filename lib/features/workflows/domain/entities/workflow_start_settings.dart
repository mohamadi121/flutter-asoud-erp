import 'workflow_definition.dart';

class WorkflowStartSettings {
  const WorkflowStartSettings(
      {this.manual = false,
      this.source,
      this.roles = const ['System Manager'],
      this.allowManagerRestart = false,
      this.sourceRoute = 'Available',
      this.hasVersion1 = false});
  factory WorkflowStartSettings.fromDesign(WorkflowDesign design) {
    final start = design.stages
        .where((s) => s.type == WorkflowStageType.start)
        .firstOrNull;
    final config = start?.config ?? const <String, dynamic>{};
    final bool hasVersion1 = config['start_settings_version'] == 1;
    final sources = design.stages
        .map((s) => s.config['submission_source'])
        .whereType<Map>();
    final source = config['submission_source'] is Map
        ? config['submission_source'] as Map
        : sources.firstOrNull;
    return WorkflowStartSettings(
        manual: source == null && config['trigger_type'] == 'Manual' && (hasVersion1 || start?.configurationComplete == true),
        sourceRoute: config['source_route'] as String? ?? (source == null ? 'Available' : 'Default'),
        source: source == null ? null : Map<String, dynamic>.from(source),
        roles: config['initiator_roles'] is List
            ? (config['initiator_roles'] as List).whereType<String>().toList()
            : const ['System Manager'],
        allowManagerRestart: config['allow_manager_restart'] == true,
        hasVersion1: hasVersion1);
  }
  final bool manual, allowManagerRestart, hasVersion1;
  final String sourceRoute;
  final Map<String, dynamic>? source;
  final List<String> roles;
  WorkflowStartSettings copyWith(
          {bool? manual,
          Map<String, dynamic>? source,
          bool clearSource = false,
          List<String>? roles,
          bool? allowManagerRestart,
          bool? hasVersion1}) =>
      WorkflowStartSettings(
          manual: manual ?? this.manual,
          source: clearSource ? null : source ?? this.source,
          roles: roles ?? this.roles,
          allowManagerRestart: allowManagerRestart ?? this.allowManagerRestart,
          sourceRoute: sourceRoute,
          hasVersion1: hasVersion1 ?? this.hasVersion1);
  WorkflowStartSettings withSourceRoute(String mode) => WorkflowStartSettings(
    manual: manual, source: source, roles: roles, allowManagerRestart: allowManagerRestart,
    hasVersion1: hasVersion1, sourceRoute: mode);
  Map<String, dynamic> toMap() => {
        'trigger_type': manual ? 'Manual' : 'Document Event',
        'source_route': manual ? 'Available' : sourceRoute,
        'initiator_roles': roles,
        'submission_source': manual || source == null
            ? null
            : {'form': source!['form'], 'revision': source!['revision']},
        'allow_manager_restart': allowManagerRestart,
        'require_manual_reason': true
      };
  Map<String, dynamic> get storedConfig => {
        ...toMap(),
        if (!manual) 'submission_source': source,
        'start_settings_version': 1,
        'prevent_duplicate': true,
        'prevent_restart': true,
        'audit_start': true,
        'subject_source': manual ? 'General Subject' : 'Referenced Document',
        'pass_mode': 'Direct'
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowStartSettings &&
          runtimeType == other.runtimeType &&
          manual == other.manual &&
          allowManagerRestart == other.allowManagerRestart &&
          hasVersion1 == other.hasVersion1 &&
          sourceRoute == other.sourceRoute &&
          _mapEquals(source, other.source) &&
          _listEquals(roles, other.roles);

  @override
  int get hashCode =>
      Object.hash(manual, allowManagerRestart, hasVersion1, sourceRoute,
          source == null ? null : Object.hashAll((source!.keys.toList()..sort()).map((key) => Object.hash(key, source![key]))), Object.hashAll(roles));

  bool _mapEquals(Map? a, Map? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }

  bool _listEquals(List a, List b) {
    if (a == b) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

abstract interface class WorkflowStartSettingsRepository {
  bool get localStartSettings;
  Future<WorkflowStage> configureStart(
      String definition, WorkflowStartSettings settings);
}

abstract interface class WorkflowDraftStartRepository {
  Future<void> validateStartSelection(String company, WorkflowStartSettings settings, {String? definition});
  Future<WorkflowDefinition> createInitializedDraft(Map<String, dynamic> info, WorkflowStartSettings settings);
}
