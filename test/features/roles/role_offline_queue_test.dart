import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

const _offline = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

/// Mimics the real client's queue: writes through [callAsoudMethod] are
/// staged as mutation rows (payload carries `operation`) before the transport
/// runs; [callMethod] never stages anything.
class _QueueingClient implements FrappeApiClient {
  _QueueingClient(this.store);
  final FakeLocalRecordStore store;
  bool offline = true;
  int asoudWrites = 0;
  int rawWrites = 0;
  final asoudTargets = <String>[];

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'manager',
        fullName: 'Manager',
        roles: ['System Manager'],
      );

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.save_role') ||
        method.endsWith('.create_category') ||
        method.endsWith('.apply_templates')) {
      asoudWrites++;
      asoudTargets.add(method);
      if (offline) {
        await store.save(
          entityType: method,
          payload: {
            ...?data,
            'operation': 'asoud_method',
            '_asoud_owner': 'manager',
            '_asoud_server': 'test',
          },
          status: LocalSyncStatus.pendingSync,
        );
        throw _offline;
      }
      final payload =
          Map<String, dynamic>.from((data?['payload'] ?? data ?? {}) as Map);
      return {
        'code': payload['code'] ?? 'ROLE',
        'title': payload['title'] ?? 'نقش',
        'category': payload['category'] ?? 'CAT',
        'parent': payload['parent'] ?? '',
        'description': payload['description'] ?? '',
        'enabled': true,
        'base_roles': payload['base_roles'] ?? const [],
        'modified': payload['modified'],
        'profile_modified': payload['profile_modified'],
        'assigned_users': 0,
      };
    }
    throw StateError('Unexpected asoud method: $method');
  }

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.catalog')) {
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
    if (method.endsWith('.save_role') ||
        method.endsWith('.create_category') ||
        method.endsWith('.apply_templates')) {
      rawWrites++;
      if (offline) throw _offline;
      throw StateError('Unexpected online raw write: $method');
    }
    throw StateError('Unexpected raw method: $method');
  }

  @override
  Future<FrappeSession> login(
          {required String username, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getResourceList(String doctype,
          {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> createResource(
          String doctype, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> updateResource(
          String doctype, String name, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<dynamic> replayOfflineMutation(
          {required String mutationId,
          required String operation,
          required String target,
          required Map<String, dynamic> data}) =>
      throw UnimplementedError();
}

void main() {
  test('role save offline stages a mutation and synchronize replays it once',
      () async {
    final store = FakeLocalRecordStore();
    final client = _QueueingClient(store);
    final repository = RoleRepository(client, local: store);
    addTearDown(repository.dispose);

    const role = ManagedRole(
      code: 'CASHIER',
      title: 'صندوقدار',
      category: 'FIN',
      baseRoles: [],
    );

    // Offline save: must go through the queued writer, not the raw one.
    await repository.save(role);
    expect(client.asoudWrites, 1);
    expect(client.rawWrites, 0);

    final staged = store.records.values
        .where((row) => row.payload['operation'] is String)
        .toList(growable: false);
    expect(staged, hasLength(1));
    expect(repository.pendingCount, 1);
    expect(repository.localCatalog.roles.any((row) => row.code == 'CASHIER'),
        isTrue);

    // Reconnect: manual "synchronize" replays the draft exactly once and the
    // local draft disappears.
    client.offline = false;
    client.asoudWrites = 0;
    await repository.synchronize();

    expect(client.asoudWrites, 1);
    expect(client.rawWrites, 0);
    expect(repository.pendingCount, 0);
    expect(repository.isDraft('CASHIER'), isFalse);
    final stillPending = store.records.values.where((row) =>
        row.payload['operation'] is String &&
        row.status != LocalSyncStatus.synced);
    expect(stillPending, isEmpty);
  });
}
