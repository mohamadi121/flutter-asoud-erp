import 'workflow_definition.dart';

class WorkflowStartSettings {
  const WorkflowStartSettings(
      {this.manual = false,
      this.source,
      this.roles = const ['System Manager'],
      this.allowManagerRestart = false});
  factory WorkflowStartSettings.fromDesign(WorkflowDesign design) {
    final start = design.stages
        .where((s) => s.type == WorkflowStageType.start)
        .firstOrNull;
    final config = start?.config ?? const <String, dynamic>{};
    final sources = design.stages
        .map((s) => s.config['submission_source'])
        .whereType<Map>();
    final source = config['submission_source'] is Map
        ? config['submission_source'] as Map
        : sources.firstOrNull;
    return WorkflowStartSettings(
        manual: source == null && config['trigger_type'] == 'Manual',
        source: source == null ? null : Map<String, dynamic>.from(source),
        roles: config['initiator_roles'] is List &&
                (config['initiator_roles'] as List).isNotEmpty
            ? (config['initiator_roles'] as List).whereType<String>().toList()
            : const ['System Manager'],
        allowManagerRestart: config['allow_manager_restart'] == true);
  }
  final bool manual, allowManagerRestart;
  final Map<String, dynamic>? source;
  final List<String> roles;
  WorkflowStartSettings copyWith(
          {bool? manual,
          Map<String, dynamic>? source,
          bool clearSource = false,
          List<String>? roles,
          bool? allowManagerRestart}) =>
      WorkflowStartSettings(
          manual: manual ?? this.manual,
          source: clearSource ? null : source ?? this.source,
          roles: roles ?? this.roles,
          allowManagerRestart: allowManagerRestart ?? this.allowManagerRestart);
  Map<String, dynamic> toMap() => {
        'trigger_type': manual ? 'Manual' : 'Document Event',
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
}

abstract interface class WorkflowStartSettingsRepository {
  bool get localStartSettings;
  Future<WorkflowStage> configureStart(
      String definition, WorkflowStartSettings settings);
}
