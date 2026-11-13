import '../../../core/network/frappe_client.dart';
import '../domain/entities/workflow_definition.dart';

/// Uses the existing side-effect-free evaluator and scoped master-data APIs.
class WorkflowConditionRepository {
  const WorkflowConditionRepository(this.client);
  final FrappeApiClient client;

  Future<Map<String, dynamic>> test({required String definition, required String stage,
      required Map<String, dynamic> config, required Map<String, dynamic> samples}) async {
    final response = await client.callMethod('asoud_erp.api.v1.workflow.test_workflow_condition',
      data: {'definition': definition, 'stage': stage, 'config': config, 'samples': samples});
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || envelope['data'] is! Map) {
      throw StateError('پاسخ آزمایش شرط معتبر نیست.');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> choices(String definition, String stage, WorkflowFieldOption field, String query) async {
    final response = await client.callAsoudMethod('asoud_erp.api.v1.workflow.workflow_condition_fields', data: {
      'definition': definition, 'stage': stage, 'value_field': field.name,
      'value_source_kind': field.source, 'value_source_stage': field.sourceStage, 'query': query,
    });
    final result = response is Map ? response['value_options'] : null;
    if (result is! List) throw StateError('فهرست گزینه‌ها دریافت نشد.');
    return result.whereType<Map>().map((row) => <String, dynamic>{
      'value': row['value'] ?? row['name'], 'label': row['label'] ?? row['value'] ?? row['name'],
    }).toList();
  }
}
