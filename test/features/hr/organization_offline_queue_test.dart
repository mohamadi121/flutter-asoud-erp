import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/domain/organization_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

const _offline = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

/// Mimics the real client's queue: [callAsoudMethod] stages a mutation row
/// before the transport runs; [callMethod] never stages anything.
class _QueueingClient implements FrappeApiClient {
  _QueueingClient(this.store);
  final FakeLocalRecordStore store;
  bool offline = true;
  int asoudWrites = 0;
  int rawWrites = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'hr-manager',
        fullName: 'HR',
        roles: ['HR Manager'],
      );

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.save_chart')) {
      asoudWrites++;
      if (offline) {
        await store.save(
          entityType: method,
          payload: {
            ...?data,
            'operation': 'asoud_method',
            '_asoud_owner': 'hr-manager',
            '_asoud_server': 'test-server',
          },
          status: LocalSyncStatus.pendingSync,
        );
        throw _offline;
      }
      final payload =
          Map<String, dynamic>.from((data?['payload'] ?? {}) as Map);
      return {
        'rows': payload['rows'],
        'revision': (payload['revision'] as num).toInt() + 1,
      };
    }
    throw StateError('Unexpected asoud method: $method');
  }

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.save_chart')) {
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
  test('organization save offline stages a mutation; manual save replays once',
      () async {
    final store = FakeLocalRecordStore();
    final client = _QueueingClient(store);
    final repository = OrganizationRepository(client, local: store);
    addTearDown(repository.dispose);

    final saved = await repository.save('شرکت نمونه', standardOrganization, 3);
    expect(saved.pending, isTrue);
    expect(client.asoudWrites, 1);
    expect(client.rawWrites, 0);

    final staged = store.records.values
        .where((row) => row.payload['operation'] is String)
        .toList(growable: false);
    expect(staged, hasLength(1));

    final drafts = store.records.values
        .where((row) => row.entityType == 'organization_draft')
        .toList(growable: false);
    expect(drafts, hasLength(1));

    // Reconnect: saving again ("همگام‌سازی") replays exactly once and the
    // local draft is cleared.
    client.offline = false;
    client.asoudWrites = 0;
    final replayed =
        await repository.save('شرکت نمونه', standardOrganization, 3);

    expect(client.asoudWrites, 1);
    expect(client.rawWrites, 0);
    expect(replayed.pending, isFalse);
    expect(replayed.revision, 4);
    expect(
        store.records.values
            .where((row) => row.entityType == 'organization_draft'),
        isEmpty);
    final stillPending = store.records.values.where((row) =>
        row.payload['operation'] is String &&
        row.status != LocalSyncStatus.synced);
    expect(stillPending, isEmpty);
  });
}
