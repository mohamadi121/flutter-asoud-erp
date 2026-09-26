import '../../../core/network/frappe_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../domain/role_catalog.dart';

class RoleRepository {
  const RoleRepository(this.client);
  final FrappeApiClient client;
  static const _api = 'asoud_erp.api.v1.role_management';

  Future<dynamic> _call(String method, {Map<String, dynamic>? data}) async {
    // Security mutations must not be replayed later by the generic offline queue.
    final response = await client.callMethod(method, data: data);
    final envelope = response['message'];
    if (envelope is! Map ||
        envelope['meta'] is! Map ||
        (envelope['meta'] as Map)['api_version'] != 'v1') {
      throw const ApiException.protocol();
    }
    return AsoudApiResponse<dynamic>.parse(
        Map<String, dynamic>.from(envelope), (value) => value).data;
  }

  Future<RoleCatalog> load() async {
    final value =
        await _call('$_api.catalog').timeout(const Duration(seconds: 12));
    return RoleCatalog.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<ManagedRole> save(ManagedRole role) async {
    final value =
        await _call('$_api.save_role', data: {'payload': role.toJson()})
            .timeout(const Duration(seconds: 25));
    return ManagedRole.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<RoleCategory> createCategory(
      String code, String title, String style) async {
    final value = await _call('$_api.create_category', data: {
      'payload': {'code': code, 'title': title, 'style': style}
    }).timeout(const Duration(seconds: 20));
    return RoleCategory.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<void> applyTemplates(List<String> codes) async {
    await _call('$_api.apply_templates', data: {'codes': codes})
        .timeout(const Duration(seconds: 30));
  }

  Future<List<RolePermissionRow>> preview(List<String> roles) async {
    final value =
        await _call('$_api.permission_preview', data: {'roles': roles})
            .timeout(const Duration(seconds: 20));
    return (value as List)
        .map((row) =>
            RolePermissionRow.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
