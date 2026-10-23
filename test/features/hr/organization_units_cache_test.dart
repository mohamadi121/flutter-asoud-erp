import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

class _UnitsClient extends Fake implements FrappeApiClient {
  bool offline = false;
  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'hr', fullName: 'HR', roles: ['HR Manager']);
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (offline) {
      throw const ApiException(
          kind: ApiFailureKind.network, message: 'offline');
    }
    return {
      'message': {
        'ok': true,
        'meta': {'api_version': 'v1'},
        'data': {
          'units': [
            {
              'name': 'HR-CO',
              'department_name': 'منابع انسانی',
              'parent_department': 'All Departments',
              'is_group': 0,
              'disabled': 0,
              'modified': '2026-10-22 10:00:00'
            }
          ],
          'can_manage': true
        },
      },
    };
  }
}

void main() {
  test('units come from the offline cache when the server is unreachable',
      () async {
    final client = _UnitsClient();
    final repo = OrganizationRepository(client, local: FakeLocalRecordStore());
    addTearDown(repo.dispose);
    await repo.units('شرکت');
    client.offline = true;
    final cached = await repo.units('شرکت');
    expect((cached['units'] as List).single['name'], 'HR-CO');
  });

  test('without a cache an offline failure is still raised', () async {
    final client = _UnitsClient()..offline = true;
    final repo = OrganizationRepository(client, local: FakeLocalRecordStore());
    addTearDown(repo.dispose);
    expect(repo.units('شرکت'), throwsA(anything));
  });
}
