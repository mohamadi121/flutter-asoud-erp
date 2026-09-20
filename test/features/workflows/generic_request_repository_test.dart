import 'dart:async';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
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
  late String user;
  late Object? failure;
  late List<Map> writes;
  setUp(() {
    client = _Client(); store = FakeLocalRecordStore(); user = 'employee'; failure = null; writes = [];
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.authenticationChanges).thenAnswer((_) => const Stream.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async => FrappeUserContext(
      userId: user, fullName: user, roles: const ['Employee']));
    when(() => client.callAsoudMethod(any(), data: any(named: 'data'))).thenAnswer((call) async {
      final method = call.positionalArguments.first as String;
      if (method.endsWith('create_request')) writes.add(Map.from(call.namedArguments[#data] as Map));
      if (failure != null) throw failure!;
      return method.endsWith('create_request') || method.endsWith('get_request')
        ? {'name': 'REQ-1', 'subject': 'Request', 'status': 'Running'} : <dynamic>[];
    });
    repo = GenericRequestRepository(client, 'office', store: store);
  });
  tearDown(() => repo.dispose());
  const offline = ApiException(kind: ApiFailureKind.network, message: 'offline');
  test('durable queue replays the same ID and attachment after restart', () async {
    failure = offline;
    await repo.create({'subject': 'Request', 'attachments': [{'filename': 'a.pdf', 'content_base64': 'YWJj'}]}, 'stable-request-id');
    expect((await store.list(entityType: 'generic_request_outbox')).single.status, LocalSyncStatus.pendingSync);
    repo.dispose(); repo = GenericRequestRepository(client, 'office', store: store);
    failure = null; await repo.sync();
    expect(writes.length, 2);
    expect(writes.first, writes.last);
    expect(writes.last['request_id'], 'stable-request-id');
    failure = offline;
    expect((await repo.list()).single['name'], 'REQ-1');
    expect((await repo.detail('REQ-1'))['subject'], 'Request');
  });
  test('permission failures cannot use cache and failed mutation is retained', () async {
    await repo.options();
    failure = const ApiException(kind: ApiFailureKind.forbidden, message: 'denied');
    await expectLater(repo.options(), throwsA(isA<ApiException>()));
    await repo.create({'subject': 'Request'}, 'stable-request-id');
    final record = (await store.list(entityType: 'generic_request_outbox')).single;
    expect(record.status, LocalSyncStatus.syncFailed);
    expect(record.payload['data']['subject'], 'Request');
    await repo.sync(); expect(writes, hasLength(1));
    failure = null; await repo.sync(retry: true); expect(writes, hasLength(2));
  });
  test('another account cannot replay or view the queued request', () async {
    failure = offline;
    await repo.create({'subject': 'Request'}, 'stable-request-id');
    final key = (await store.list(entityType: 'generic_request_outbox')).single.id;
    user = 'other';
    expect(await repo.list(), isEmpty);
    await expectLater(repo.detail(key), throwsStateError);
    expect(writes, hasLength(1));
  });
  test('same ID cannot overwrite a queued payload', () async {
    failure = offline;
    await repo.create({'subject': 'Request'}, 'stable-request-id');
    await expectLater(repo.create({'subject': 'Changed'}, 'stable-request-id'), throwsStateError);
    expect((await store.list(entityType: 'generic_request_outbox')).single.payload['data']['subject'], 'Request');
  });
}
