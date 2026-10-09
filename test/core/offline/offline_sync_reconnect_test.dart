import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_lifecycle.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Counts how often the lifecycle actually asks the service to sync, so the
/// guest-session guard is observable and not just "nothing happened".
class _CountingSyncService extends OfflineSyncService {
  _CountingSyncService(super.client, {required super.local});

  var syncCalls = 0;

  @override
  Future<OfflineSyncReport> syncNow() {
    syncCalls++;
    return super.syncNow();
  }
}

class _LifecycleClient extends Fake implements FrappeApiClient {
  bool authenticated = true;
  final replays = <String>[];

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'user', fullName: 'کاربر آزمون', roles: []);

  @override
  Future<dynamic> replayOfflineMutation({
    required String mutationId,
    required String operation,
    required String target,
    required Map<String, dynamic> data,
  }) async {
    replays.add(mutationId);
    return {'name': 'REMOTE-1'};
  }
}

Future<void> _queue(FakeLocalRecordStore store, String id) => store.save(
      id: id,
      entityType: 'asoud_erp.api.v1.party.save_party',
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': 'user',
        '_asoud_server': 'injected-client',
        'name': 'PARTY-$id',
      },
      status: LocalSyncStatus.pendingSync,
    );

Future<void> _mount(
  WidgetTester tester, {
  required OfflineSyncService service,
  required Stream<bool> online,
  Duration interval = const Duration(minutes: 5),
}) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.rtl,
    child: OfflineSyncLifecycle(
      service: service,
      interval: interval,
      onlineChanges: online,
      child: const SizedBox.shrink(),
    ),
  ));
  // Flush the first-frame sync and every queued microtask.
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('بازگشت اتصال صف را یک بار و پس از مهلت دوباره‌ثانیه‌ای می‌فرستد',
      (tester) async {
    final store = FakeLocalRecordStore();
    final client = _LifecycleClient();
    final service = OfflineSyncService(client, local: store);
    final online = StreamController<bool>();
    addTearDown(online.close);
    await _mount(tester, service: service, online: online.stream);
    expect(client.replays, isEmpty);

    await _queue(store, 'one');
    await _queue(store, 'two');
    online
      ..add(false)
      ..add(true);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(client.replays, isEmpty,
        reason: 'تا پایان مهلت ۲ ثانیه‌ای نباید ارسالی آغاز شود');

    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(client.replays, ['one', 'two'],
        reason: 'یک بازگشت به شبکه تنها یک دور ارسال می‌سازد');

    // A flapping connection must not replay the same rows again.
    await _queue(store, 'three');
    online
      ..add(true)
      ..add(false)
      ..add(true);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(client.replays, ['one', 'two', 'three']);
  });

  testWidgets('در نبود نشست، تایمر و بازگشت اتصال صف را بیدار نمی‌کنند',
      (tester) async {
    final store = FakeLocalRecordStore();
    final client = _LifecycleClient()..authenticated = false;
    final service = _CountingSyncService(client, local: store);
    final online = StreamController<bool>();
    addTearDown(online.close);
    await _mount(tester,
        service: service,
        online: online.stream,
        interval: const Duration(seconds: 30));

    await _queue(store, 'one');
    await _settle(tester);
    expect(service.syncCalls, 0, reason: 'در فریم اول هم نشستی وجود ندارد');

    await tester.pump(const Duration(seconds: 31));
    await _settle(tester);
    expect(service.syncCalls, 0, reason: 'تایمر در حالت مهمان بیهوده می‌چرخد');

    online.add(true);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    expect(service.syncCalls, 0,
        reason: 'بازگشت اتصال بدون نشست نباید صف را لمس کند');
    expect(client.replays, isEmpty,
        reason: 'بدون نشست کاربر چیزی برای ارسال وجود ندارد');

    client.authenticated = true;
    online.add(true);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(service.syncCalls, 1,
        reason: 'با برگشت نشست، بازگشت اتصال صف را می‌فرستد');
    expect(client.replays, ['one']);
  });
}
