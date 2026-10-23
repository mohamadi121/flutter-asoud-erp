import '../../../core/network/frappe_client.dart';

/// Receipt confirmation of issued equipment (backend `request_followup`,
/// docs/api/form-execution.md). Kept apart from `WorkflowTaskRepository` so
/// existing fakes of that interface stay valid.
abstract interface class ReceiptConfirmationRepository {
  Future<void> confirm(String task);
  Future<void> reject(String task, String reason);
}

class FrappeReceiptConfirmationRepository
    implements ReceiptConfirmationRepository {
  FrappeReceiptConfirmationRepository(this._client);
  final FrappeClient _client;

  static const _prefix = 'asoud_erp.api.v1.request_followup.';

  @override
  Future<void> confirm(String task) async {
    await _client.callAsoudMethod('${_prefix}confirm_receipt',
        data: {'task': task});
  }

  @override
  Future<void> reject(String task, String reason) async {
    await _client.callAsoudMethod('${_prefix}reject_receipt',
        data: {'task': task, 'reason': reason.trim()});
  }
}
