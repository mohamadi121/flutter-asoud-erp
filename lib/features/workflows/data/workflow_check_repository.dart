import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';

/// Read-only server calls for the workflow validity check and the
/// side-effect-free simulation (`asoud_erp.api.v1.workflow.validate_workflow`
/// and `simulate_workflow`). Both are read-only on the server and registered
/// in `FrappeClient.isReadOnlyMethod` so neither is queued for offline replay.
class WorkflowCheckRepository {
  const WorkflowCheckRepository(this.client);

  final FrappeApiClient client;

  static const validateMethod = 'asoud_erp.api.v1.workflow.validate_workflow';
  static const simulateMethod = 'asoud_erp.api.v1.workflow.simulate_workflow';

  /// `{"ok": bool, "issues": [{code, severity, message, stage, route}]}`
  Future<Map<String, dynamic>> validate(String definition) async {
    final data = await client.callAsoudMethod(validateMethod,
        data: {'definition': definition});
    if (data is! Map || data['ok'] is! bool || data['issues'] is! List) {
      throw const ApiException.protocol();
    }
    return Map<String, dynamic>.from(data);
  }

  /// `{"steps": [...], "status", "waiting_stage", "allowed_actions",
  /// "outcome", "errors"}`
  Future<Map<String, dynamic>> simulate(
      String definition, List<Map<String, String>> decisions) async {
    final data = await client.callAsoudMethod(simulateMethod,
        data: {'definition': definition, 'decisions': decisions});
    if (data is! Map ||
        data['steps'] is! List ||
        data['status'] is! String ||
        data['allowed_actions'] is! List ||
        data['errors'] is! List) {
      throw const ApiException.protocol();
    }
    return Map<String, dynamic>.from(data);
  }
}
