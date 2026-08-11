import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  test('صف به‌ترتیب Replay و رکورد دامنه synced می‌شود', () async {
    final local = FakeLocalRecordStore();
    await local.save(
      id: 'mutation-1',
      entityType: 'asoud_erp.api.v1.setup.save_office',
      payload: const {
        'operation': 'asoud_method',
        'company_name': 'دفتر نمونه',
      },
      status: LocalSyncStatus.pendingSync,
    );
    await local.save(
      id: 'office:sample',
      entityType: 'office',
      payload: const {'company': 'دفتر نمونه'},
      status: LocalSyncStatus.pendingSync,
    );
    final client = _ReplayClient();

    final report = await OfflineSyncService(client, local: local).syncNow();

    expect(report.synced, 1);
    expect(report.remaining, 0);
    expect(local.records['mutation-1']!.status, LocalSyncStatus.synced);
    expect(local.records['office:sample']!.status, LocalSyncStatus.synced);
    expect(client.targets, ['asoud_erp.api.v1.setup.save_office']);
  });

  test('خطای شبکه رکورد را pending نگه می‌دارد', () async {
    final local = FakeLocalRecordStore();
    await _mutation(local, 'mutation-1');
    final client = _ReplayClient(error: _networkError);

    final report = await OfflineSyncService(client, local: local).syncNow();

    expect(report.synced, 0);
    expect(report.remaining, 1);
    expect(local.records['mutation-1']!.status, LocalSyncStatus.pendingSync);
  });

  test('خطای اعتبارسنجی syncFailed می‌شود و از صف خودکار خارج می‌شود',
      () async {
    final local = FakeLocalRecordStore();
    await _mutation(local, 'mutation-1');
    const validation = ApiException(
      kind: ApiFailureKind.validation,
      message: 'invalid',
    );

    final report = await OfflineSyncService(
      _ReplayClient(error: validation),
      local: local,
    ).syncNow();

    expect(report.failed, 1);
    expect(report.remaining, 0);
    expect(local.records['mutation-1']!.status, LocalSyncStatus.syncFailed);
  });

  test('فراخوانی هم‌زمان فقط یک Replay ایجاد می‌کند', () async {
    final local = FakeLocalRecordStore();
    await _mutation(local, 'mutation-1');
    final gate = Completer<void>();
    final client = _ReplayClient(gate: gate.future);
    final service = OfflineSyncService(client, local: local);

    final first = service.syncNow();
    final second = service.syncNow();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);

    expect(client.replayCalls, 1);
  });
}

Future<void> _mutation(FakeLocalRecordStore local, String id) => local.save(
      id: id,
      entityType: 'asoud_erp.api.v1.test.save',
      payload: const {'operation': 'asoud_method', 'value': 1},
      status: LocalSyncStatus.pendingSync,
    );

const _networkError = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

class _ReplayClient implements FrappeApiClient {
  _ReplayClient({this.error, this.gate});
  final Object? error;
  final Future<void>? gate;
  int replayCalls = 0;
  final targets = <String>[];

  @override
  Future<dynamic> replayOfflineMutation({
    required String mutationId,
    required String operation,
    required String target,
    required Map<String, dynamic> data,
  }) async {
    replayCalls++;
    targets.add(target);
    if (gate != null) await gate;
    if (error != null) throw error!;
    return {'name': 'REMOTE-1'};
  }

  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
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
  Future<FrappeUserContext> getCurrentUser() => throw UnimplementedError();
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
