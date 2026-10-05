import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_failure.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

const _offline = ApiException(
  kind: ApiFailureKind.network,
  message: 'ارتباط با سرور برقرار نشد.',
);

const _office = 'asoud_erp.api.v1.setup.save_office';
const _party = 'asoud_erp.api.v1.party.save_party';

class _QueueClient extends Fake implements FrappeApiClient {
  bool authenticated = true;
  Object? error;
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
    if (error != null) throw error!;
    return {'name': 'REMOTE-1'};
  }
}

Future<LocalRecord> _queue(
  FakeLocalRecordStore store,
  String id, {
  required String target,
  String? recordId,
  LocalSyncStatus status = LocalSyncStatus.pendingSync,
  int attempts = 0,
  DateTime? nextAttemptAt,
  Map<String, dynamic> extra = const {},
}) =>
    store.save(
      id: id,
      entityType: target,
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': 'user',
        '_asoud_server': 'injected-client',
        if (recordId != null) 'name': recordId,
        ...extra,
      },
      status: status,
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
    );

void main() {
  test('فاصله تلاش‌های ناموفق ۳۰ ثانیه، ۱، ۲، ۵، ۱۵ و ۳۰ دقیقه است', () {
    expect(OfflineSyncService.backoffFor(1), const Duration(seconds: 30));
    expect(OfflineSyncService.backoffFor(2), const Duration(minutes: 1));
    expect(OfflineSyncService.backoffFor(3), const Duration(minutes: 2));
    expect(OfflineSyncService.backoffFor(4), const Duration(minutes: 5));
    expect(OfflineSyncService.backoffFor(5), const Duration(minutes: 15));
    expect(OfflineSyncService.backoffFor(6), const Duration(minutes: 30));
    expect(OfflineSyncService.backoffFor(7), const Duration(minutes: 30));
    expect(OfflineSyncService.backoffFor(40), const Duration(minutes: 30));
  });

  test('هر تلاش ناموفق شمارش و موعد تلاش بعدی را دقیقاً ذخیره می‌کند',
      () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'one', target: _office);
    final client = _QueueClient()..error = _offline;
    var now = DateTime.utc(2026, 10, 5, 8);
    const schedule = [
      (attempt: 1, wait: Duration(seconds: 30)),
      (attempt: 2, wait: Duration(minutes: 1)),
      (attempt: 3, wait: Duration(minutes: 2)),
      (attempt: 4, wait: Duration(minutes: 5)),
      (attempt: 5, wait: Duration(minutes: 15)),
      (attempt: 6, wait: Duration(minutes: 30)),
      (attempt: 7, wait: Duration(minutes: 30)),
    ];
    for (final step in schedule) {
      final service =
          OfflineSyncService(client, local: store, clock: () => now);
      await service.syncNow();
      final row = store.records['one']!;
      expect(row.attempts, step.attempt);
      expect(row.status, LocalSyncStatus.pendingSync);
      expect(row.nextAttemptAt, now.add(step.wait));

      final replays = client.replays.length;
      await service.syncNow();
      expect(client.replays.length, replays,
          reason: 'پیش از موعد نباید دوباره تلاش کند');
      now = row.nextAttemptAt!;
    }
    expect(client.replays, List.filled(7, 'one'));
  });

  for (final failure in [
    (kind: ApiFailureKind.validation, code: 400),
    (kind: ApiFailureKind.validation, code: 417),
    (kind: ApiFailureKind.forbidden, code: 403),
    (kind: ApiFailureKind.conflict, code: 409),
  ]) {
    test('خطای ${failure.code} پایدار است و خودکار تکرار نمی‌شود', () async {
      final store = FakeLocalRecordStore();
      await _queue(store, 'one', target: _office);
      final client = _QueueClient()
        ..error = ApiException(
          kind: failure.kind,
          message: 'نام تکراری است',
          statusCode: failure.code,
        );
      final service = OfflineSyncService(client, local: store);

      final report = await service.syncNow();

      expect(report.failed, 1);
      expect(report.remaining, 1, reason: 'ردیف ناموفق هنوز ارسال‌نشده است');
      await service.syncNow();
      await service.syncNow();
      expect(client.replays, ['one'],
          reason: 'خطای ورودی نباید خودکار تکرار شود');

      final row = store.records['one']!;
      expect(row.status, LocalSyncStatus.syncFailed);
      expect(row.attempts, 1);
      expect(row.lastError, 'نام تکراری است');
      expect(row.nextAttemptAt, isNull, reason: 'خطای پایدار موعد تلاش ندارد');
      expect((await service.unsent()).map((row) => row.id), ['one'],
          reason: 'کاربر باید آن را در صف ببیند');
    });
  }

  test('تلاش دوباره شمارش و موعد را از نو می‌سازد', () async {
    final store = FakeLocalRecordStore();
    final now = DateTime.utc(2026, 10, 5, 8);
    await _queue(
      store,
      'one',
      target: _office,
      status: LocalSyncStatus.syncFailed,
      attempts: 6,
      nextAttemptAt: DateTime.utc(2099),
    );
    final client = _QueueClient()..error = _offline;
    final service = OfflineSyncService(client, local: store, clock: () => now);

    await service.retry('one');

    expect(client.replays, ['one']);
    final row = store.records['one']!;
    expect(row.attempts, 1);
    expect(row.status, LocalSyncStatus.pendingSync);
    expect(row.nextAttemptAt, now.add(const Duration(seconds: 30)));
  });

  test('تلاش دوباره تنها راه ارسال یک خطای پایدار است', () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'one', target: _office);
    final client = _QueueClient()
      ..error = const ApiException(
        kind: ApiFailureKind.validation,
        message: 'نام تکراری است',
        statusCode: 409,
      );
    final service = OfflineSyncService(client, local: store);

    await service.syncNow();
    expect(store.records['one']!.status, LocalSyncStatus.syncFailed);
    client.error = null;
    await service.retry('one');

    expect(client.replays, ['one', 'one']);
    expect(store.records['one']!.status, LocalSyncStatus.synced);
    expect(await service.unsentCount(), 0);
  });

  test('ردیف ناموفق جلوی ردیف‌های همان رکورد را می‌گیرد و بقیه ارسال می‌شوند',
      () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'blocked',
        target: _party,
        recordId: 'PARTY-1',
        status: LocalSyncStatus.syncFailed);
    await _queue(store, 'successor', target: _party, recordId: 'PARTY-1');
    await _queue(store, 'other', target: _party, recordId: 'PARTY-2');
    final client = _QueueClient();
    final service = OfflineSyncService(client, local: store);

    final report = await service.syncNow();

    expect(client.replays, ['other']);
    expect(report.synced, 1);
    expect(report.remaining, 2);
    expect(store.records['successor']!.status, LocalSyncStatus.pendingSync);
  });

  test('ردیفی که موعدش نرسیده جلوی وابسته‌های همان رکورد را می‌گیرد', () async {
    final store = FakeLocalRecordStore();
    final now = DateTime.utc(2026, 10, 5, 8);
    await _queue(store, 'waiting',
        target: _party,
        recordId: 'PARTY-1',
        attempts: 2,
        nextAttemptAt: now.add(const Duration(minutes: 2)));
    await _queue(store, 'dependent', target: _party, recordId: 'PARTY-1');
    await _queue(store, 'free', target: _party, recordId: 'PARTY-9');
    final client = _QueueClient();
    final service = OfflineSyncService(client, local: store, clock: () => now);

    final report = await service.syncNow();

    expect(client.replays, ['free']);
    expect(report.remaining, 2);
    expect(store.records['dependent']!.status, LocalSyncStatus.pendingSync);

    // Once the backoff elapses the pair replays in order.
    final later = OfflineSyncService(client,
        local: store, clock: () => now.add(const Duration(minutes: 2)));
    await later.syncNow();
    expect(client.replays, ['free', 'waiting', 'dependent']);
  });

  test('حذف از صف رکورد آینه‌ای را هم پاک می‌کند', () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'failed',
        target: _office,
        status: LocalSyncStatus.syncFailed,
        extra: {'company_name': 'دفتر نمونه'});
    await store.save(
      id: 'office:sample',
      entityType: 'office',
      payload: const {'company': 'دفتر نمونه'},
      status: LocalSyncStatus.pendingSync,
    );
    final service = OfflineSyncService(_QueueClient(), local: store);

    await service.discard('failed');

    expect(store.records.keys, isEmpty,
        reason: 'پیش‌نویس محلی نباید به‌عنوان رکورد ذخیره‌شده باقی بماند');
    expect(await service.unsentCount(), 0);
  });

  test('حذف از صف برای نوشته‌ای که آینه محلی ندارد فقط ردیف صف را پاک می‌کند',
      () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'one',
        target: 'asoud_erp.api.v1.purchase_request.create_purchase_request');
    await store.save(
      id: 'party:keep',
      entityType: 'party_profile',
      payload: const {'display_name': 'مشتری'},
      status: LocalSyncStatus.pendingSync,
    );
    final service = OfflineSyncService(_QueueClient(), local: store);

    await service.discard('one');

    expect(store.records.keys, ['party:keep']);
  });

  test('ارسال همه موعد همه ردیف‌ها را از نو می‌سازد', () async {
    final store = FakeLocalRecordStore();
    await _queue(store, 'waiting',
        target: _party,
        recordId: 'PARTY-1',
        attempts: 4,
        nextAttemptAt: DateTime.utc(2099));
    await _queue(store, 'terminal',
        target: _party,
        recordId: 'PARTY-2',
        status: LocalSyncStatus.syncFailed,
        attempts: 1);
    final client = _QueueClient();
    final service = OfflineSyncService(client, local: store);

    await service.sendAll();

    expect(client.replays, ['waiting', 'terminal']);
    expect(await service.unsentCount(), 0);
    expect(store.records['waiting']!.attempts, 0);
  });

  test('نوشته‌ای که در صف مانده خطای قابل تلاش دوباره است', () {
    expect(
      isRetryableOfflineFailure(const QueuedOfflineException(localId: 'L-1')),
      isTrue,
    );
    for (final code in terminalOfflineStatusCodes) {
      expect(
        isRetryableOfflineFailure(ApiException(
          kind: ApiFailureKind.network,
          message: 'قطع',
          statusCode: code,
        )),
        isFalse,
        reason: 'کد $code خطای ورودی است و تکرار بیهوده است',
      );
    }
  });

  test('خطای صف‌شده شناسه محلی و پیام فارسی دارد', () {
    const error = QueuedOfflineException(localId: 'LOCAL-42');
    expect(error.localId, 'LOCAL-42');
    expect(error.message, 'ذخیره شد؛ پس از اتصال ارسال می‌شود');
    expect(error.toString(), 'ذخیره شد؛ پس از اتصال ارسال می‌شود');
    expect(offlineFailureMessage(_offline), 'ارتباط با سرور برقرار نشد.');
    expect(
      offlineFailureMessage(const QueuedOfflineException(localId: 'L-2')),
      'ذخیره شد؛ پس از اتصال ارسال می‌شود',
    );
  });
}
