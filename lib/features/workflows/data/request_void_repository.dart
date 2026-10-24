import '../../../core/network/frappe_client.dart';

/// HR Manager actions on the native document of an executed request
/// (`asoud_erp.api.v1.workflow_request.void_native_document` and
/// `reissue_native_document`, docs/api/form-execution.md «Void and reissue»).
/// Both return the same detail map as `get_request`. A write made while offline
/// is queued by the client and throws `QueuedOfflineException`.
class RequestVoidRepository {
  const RequestVoidRepository(this.client);

  final FrappeApiClient client;

  static const _module = 'asoud_erp.api.v1.workflow_request';

  /// Voids the executed document; [reason] is required by the server.
  Future<Map<String, dynamic>> voidDocument(String name, String reason) =>
      _call('void_native_document', {'name': name, 'reason': reason});

  /// Runs the executor again after a void.
  Future<Map<String, dynamic>> reissue(String name) =>
      _call('reissue_native_document', {'name': name});

  Future<Map<String, dynamic>> _call(
      String method, Map<String, dynamic> data) async {
    final result = await client
        .callAsoudMethod('$_module.$method', data: data)
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result as Map);
  }
}
