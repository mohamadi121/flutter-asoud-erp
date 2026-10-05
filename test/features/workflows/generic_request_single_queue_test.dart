import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  late _Client client;
  late FakeLocalRecordStore store;
  late GenericRequestRepository repo;
  late Object? failure;
  late List<Map<String, dynamic>> rawWrites;

  setUp(() {
    client = _Client();
    store = FakeLocalRecordStore();
    failure = null;
    rawWrites = [];
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'employee', fullName: 'Employee', roles: ['Employee']));
    // Reads go through the shared writer; the create transport must not.
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.first as String;
      if (method.endsWith('create_request')) {
        throw StateError('create_request must not use the shared queue');
      }
      return <dynamic>[];
    });
    // Single queue path: the outbox replay sends the mutation itself.
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      final method = call.positionalArguments.first as String;
      if (!method.endsWith('create_request')) {
        throw StateError('Unexpected raw method: $method');
      }
      final data = Map<String, dynamic>.from(call.namedArguments[#data] as Map);
      rawWrites.add(data);
      if (failure != null) throw failure!;
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': {
            'name': 'REQ-1',
            'subject': data['subject'],
            'status': 'Running',
          },
        },
      };
    });
    repo = GenericRequestRepository(client, 'office', store: store);
  });
  tearDown(() => repo.dispose());

  const offline =
      ApiException(kind: ApiFailureKind.network, message: 'offline');

  test('one generic request creates exactly one queued mutation', () async {
    failure = offline;
    final result =
        await repo.create({'subject': 'Request'}, 'stable-request-id');

    // Still queued: the caller gets null and the request waits on device.
    expect(result, isNull);
    final rows = await store.list();
    expect(rows, hasLength(1));
    expect(rows.single.entityType, 'generic_request_outbox');
    expect(rows.single.status, LocalSyncStatus.pendingSync);
    expect(rows.single.payload['data']['request_id'], 'stable-request-id');

    // Reconnect replays exactly once with the same idempotency key.
    rawWrites.clear();
    failure = null;
    await repo.sync();
    expect(rawWrites, hasLength(1));
    expect(rawWrites.single['request_id'], 'stable-request-id');
    final after = await store.list(entityType: 'generic_request_outbox');
    expect(after.single.status, LocalSyncStatus.synced);
  });
}
