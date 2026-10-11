import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// A signed-in client whose user can change, so a sign-out/sign-in on the same
/// device is observable from the queue service.
class _OwnerClient implements FrappeApiClient {
  _OwnerClient({required this.userId});

  String userId;
  final replays = <String>[];

  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async =>
      FrappeUserContext(userId: userId, fullName: userId, roles: const []);
  @override
  Future<dynamic> replayOfflineMutation({
    required String mutationId,
    required String operation,
    required String target,
    required Map<String, dynamic> data,
  }) async {
    replays.add(mutationId);
    return {'name': 'REMOTE-$mutationId'};
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> callMethod(String method,
          {Map<String, dynamic>? data}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> createResource(
          String doctype, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getResourceList(String doctype,
          {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();
  @override
  Future<FrappeSession> login(
          {required String username, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> updateResource(
          String doctype, String name, Map<String, dynamic> data) =>
      throw UnimplementedError();
}

Future<void> _stage(
  FakeLocalRecordStore store,
  String id, {
  required String owner,
  required String server,
}) =>
    store.save(
      id: id,
      entityType: 'asoud_erp.api.v1.party.save_party',
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': owner,
        '_asoud_server': server,
        'name': 'PARTY-$id',
      },
      status: LocalSyncStatus.pendingSync,
    );

void main() {
  test('صف فقط نوشته‌های کاربر و سرور جاری را می‌بیند', () async {
    final local = FakeLocalRecordStore();
    final client = _OwnerClient(userId: 'user-a');
    final service = OfflineSyncService(client, local: local);

    await _stage(local, 'a-1', owner: 'user-a', server: 'injected-client');
    await _stage(local, 'a-2', owner: 'user-a', server: 'injected-client');
    await _stage(local, 'a-other-server',
        owner: 'user-a', server: 'https://other.example.test');

    expect((await service.unsent()).map((row) => row.id), ['a-1', 'a-2']);
    expect(await service.unsentCount(), 2,
        reason: 'ردیف سرور دیگر برای همین کاربر هم دیده نمی‌شود');
  });

  test('کاربر B نه صف A را می‌بیند، نه حذفش می‌کند، و A بعد از برگشت آن را می‌بیند',
      () async {
    final local = FakeLocalRecordStore();
    final client = _OwnerClient(userId: 'user-a');
    final service = OfflineSyncService(client, local: local);

    await _stage(local, 'a-1', owner: 'user-a', server: 'injected-client');
    await _stage(local, 'a-2', owner: 'user-a', server: 'injected-client');

    // B signs in on the same device and the same server.
    client.userId = 'user-b';
    await _stage(local, 'b-1', owner: 'user-b', server: 'injected-client');

    expect((await service.unsent()).map((row) => row.id), ['b-1'],
        reason: 'نوشته‌های A نباید در صف B دیده شوند');
    expect(await service.unsentCount(), 1);

    // B cannot discard A's rows.
    await service.discard('a-1');
    expect(local.records.containsKey('a-1'), isTrue,
        reason: 'حذف نوشته کاربر دیگر باید بی‌اثر باشد');
    await service.discardReturning('a-2');
    expect(local.records.containsKey('a-2'), isTrue,
        reason: 'حذف با بازگردانی هم نباید به نوشته کاربر دیگر دست بزند');

    // B cannot retry A's rows either.
    await service.retry('a-1');
    expect(client.replays, isEmpty,
        reason: 'تلاش دوباره روی نوشته کاربر دیگر نباید ارسال کند');

    // B can still act on their own row.
    await service.discard('b-1');
    expect(local.records.containsKey('b-1'), isFalse);

    // A signs back in and sees both writes again, untouched.
    client.userId = 'user-a';
    expect((await service.unsent()).map((row) => row.id), ['a-1', 'a-2'],
        reason: 'نوشته‌های A باید دست‌نخورده باقی مانده باشند');
  });
}
