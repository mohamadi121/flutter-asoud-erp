import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  test('queued work of the previous owner is not sent after a session switch',
      () async {
    final local = FakeLocalRecordStore();
    for (final id in ['mutation-1', 'mutation-2']) {
      await local.save(
        id: id,
        entityType: 'asoud_erp.api.v1.test.save',
        payload: {
          'operation': 'asoud_method',
          'value': id,
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
        },
        status: LocalSyncStatus.pendingSync,
      );
    }
    final client = _SwitchingClient();
    final reportFuture = OfflineSyncService(client, local: local).syncNow();

    await client.entered.future;
    client.userId = 'other';
    client.gate.complete();
    final report = await reportFuture;

    expect(client.sentIds, ['mutation-1']);
    expect(report.synced, 1);
    expect(report.remaining, 1);
    expect(local.records['mutation-1']!.status, LocalSyncStatus.synced);
    expect(local.records['mutation-2']!.status, LocalSyncStatus.pendingSync);
    expect(local.records['mutation-2']!.payload['_asoud_owner'], 'user');
  });
}

class _SwitchingClient implements FrappeApiClient {
  String userId = 'user';
  final entered = Completer<void>();
  final gate = Completer<void>();
  final sentIds = <String>[];

  @override
  Future<dynamic> replayOfflineMutation({
    required String mutationId,
    required String operation,
    required String target,
    required Map<String, dynamic> data,
  }) async {
    sentIds.add(mutationId);
    if (sentIds.length == 1) {
      entered.complete();
      await gate.future;
    }
    return {'name': 'REMOTE-$mutationId'};
  }

  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async =>
      FrappeUserContext(userId: userId, fullName: userId, roles: const []);
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
  Future<Map<String, dynamic>> updateResource(
          String doctype, String name, Map<String, dynamic> data) =>
      throw UnimplementedError();
}
