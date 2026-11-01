import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';

/// Uses the existing online runtime RPC; starting is never queued offline.
class WorkflowStartExecutionRepository {
  const WorkflowStartExecutionRepository(this.client);
  final FrappeApiClient client;

  Future<String> start(
      {required String definition,
      required String subject,
      required String reason}) async {
    final response = await client.callMethod(
        'asoud_erp.api.v1.workflow_runtime.start_workflow_instance',
        data: {'definition': definition, 'subject': subject, 'reason': reason});
    final message = response['message'];
    final data =
        message is Map && message['ok'] == true ? message['data'] : null;
    if (data is! Map ||
        data['name'] is! String ||
        (data['name'] as String).isEmpty) {
      throw const ApiException.protocol();
    }
    return data['name'] as String;
  }
}
