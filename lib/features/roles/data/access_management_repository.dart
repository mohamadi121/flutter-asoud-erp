import '../../../core/network/frappe_client.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/api_exception.dart';

class AccessManagementRepository {
  const AccessManagementRepository(this.client);
  final FrappeApiClient client;
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    // Permission changes must be accepted online, never queued as a stale grant.
    if (!client.isAuthenticated) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message: 'برای مدیریت دسترسی وارد حساب شوید.');
    }
    final response = await client
        .callMethod('asoud_erp.api.v1.access_profiles.$method', data: args);
    final body = response['message'];
    if (body is! Map) throw const ApiException.protocol();
    return AsoudApiResponse<dynamic>.parse(
        Map<String, dynamic>.from(body), (v) => v).data;
  }
}
