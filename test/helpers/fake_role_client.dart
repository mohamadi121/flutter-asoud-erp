import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic role API fixture; never opens a network connection.
class FakeRoleClient extends Fake implements FrappeApiClient {
  final methods = <String>[];

  @override
  bool get isAuthenticated => false;

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    methods.add(method);
    if (method != 'asoud_erp.api.v1.role_management.catalog') {
      throw StateError('Unexpected role API method: $method');
    }
    return {
      'message': {
        'ok': true,
        'meta': {'api_version': 'v1'},
        'data': {
          'categories': [],
          'roles': [],
          'base_roles': [],
          'templates': [],
          'template_categories': [],
        },
      },
    };
  }
}
