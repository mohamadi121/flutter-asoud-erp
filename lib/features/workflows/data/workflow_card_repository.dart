import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/utils/persian_server_values.dart';
import '../domain/entities/workflow_definition.dart';
import 'repositories/frappe_workflow_repository.dart';

/// Existing server operations, deliberately not queued as offline mutations.
class WorkflowCardRepository {
  const WorkflowCardRepository(this.client);
  final FrappeApiClient client;
  FrappeWorkflowRepository get authoritativeListing => FrappeWorkflowRepository(client);

  void _requireSession() {
    if (!client.isAuthenticated) {
      throw const ApiException(kind: ApiFailureKind.unauthenticated,
          message: 'برای تغییر گردش‌کار به حساب خود در سرور وارد شوید.');
    }
  }

  Future<Map<String, dynamic>> _call(String method, Map<String, dynamic> data) async {
    _requireSession();
    try {
      return await client.callMethod(method, data: data);
    } on ApiException catch (error) {
      if (error.kind != ApiFailureKind.validation && error.kind != ApiFailureKind.conflict) rethrow;
      final message = persianServerMessage(error.message);
      final safe = RegExp(r'[\u0600-\u06ff]').hasMatch(message) &&
          !RegExp(r'ASOUD|Frappe|ERPNext|Traceback', caseSensitive: false).hasMatch(message);
      throw ApiException(kind: error.kind, statusCode: error.statusCode, code: error.code,
          message: safe ? message : 'انجام عملیات ممکن نیست؛ گردش‌کار را از نظر تکمیل مراحل و وابستگی‌ها بررسی کنید.');
    }
  }

  Future<WorkflowDefinition> setStatus(String name, WorkflowDefinitionStatus status) async {
    final response = await _call('asoud_erp.api.v1.workflow.set_workflow_status',
        {'name': name, 'status': status == WorkflowDefinitionStatus.active ? 'Active' : 'Inactive'});
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || envelope['data'] is! Map) {
      throw const ApiException.protocol();
    }
    final updated = FrappeWorkflowRepository(client).parseDefinition(envelope['data'] as Map);
    if (updated.id != name || updated.status != status) throw const ApiException.protocol();
    return updated;
  }

  Future<void> delete(String name) async {
    await _call('frappe.client.delete', {'doctype': 'ASOUD Workflow Definition', 'name': name});
  }
}
