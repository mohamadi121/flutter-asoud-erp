import '../../../core/network/frappe_client.dart';
import '../domain/entities/workflow_definition.dart';

/// Uses native stages/transitions; validated mutations never enter an offline queue.
class WorkflowPathRepository {
  const WorkflowPathRepository(this.client);
  final FrappeApiClient client;
  Future<Map<String, dynamic>> _call(String method, Map<String, dynamic> data) async {
    final response = await client.callMethod('asoud_erp.api.v1.$method', data: data);
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('پاسخ ویرایش مسیر از سرور تأیید نشد؛ نمودار را تازه کنید.');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  Future<Map<String, dynamic>> insert(String definition, String transition, WorkflowStageType type) =>
      _call('workflow.insert_workflow_stage', {'definition': definition, 'transition': transition,
        'stage_type': switch (type) { WorkflowStageType.start => 'Start', WorkflowStageType.userTask => 'User Task',
          WorkflowStageType.approval => 'Approval', WorkflowStageType.condition => 'Condition',
          WorkflowStageType.systemAction => 'System Action', WorkflowStageType.wait => 'Wait', WorkflowStageType.end => 'End'},
        'draft_edit': 1});
  Future<void> discard(String definition, String stage, String token) async {
    await _call('workflow_paths.discard_inserted_stage',
        {'definition': definition, 'stage': stage, 'original': token});
  }
  Future<Map<String, dynamic>> preview(String definition, String transition) =>
      _call('workflow_paths.preview_path_removal', {'definition': definition, 'transition': transition});
  Future<void> remove(String definition, String transition, Object version) async {
    await _call('workflow_paths.remove_path', {'definition': definition, 'transition': transition, 'version': version});
  }
}
