import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/sync_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// «۱۴۰۵/۰۱/۰۱ - ۱۴:۰۵» — the Jalali rendering of 2026-03-21 14:05 local.
const _createdLabel = '۱۴۰۵/۰۱/۰۱ - ۱۴:۰۵';

class _QueueClient extends Fake implements FrappeApiClient {
  final replays = <String>[];

  /// When set, every replay fails with this error instead of succeeding.
  Object? failure;

  @override
  bool get isAuthenticated => true;

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
    final error = failure;
    if (error != null) throw error;
    return {'name': 'REMOTE-1'};
  }
}

final _createdAt = DateTime(2026, 3, 21, 14, 5);

Future<void> _queue(
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
      createdAt: _createdAt,
    );

Widget _app(OfflineSyncService service) => MaterialApp(
      theme: AsoudTheme.light,
      home: SyncQueuePage(service: service),
    );

Future<void> _pump(WidgetTester tester, OfflineSyncService service) async {
  await tester.pumpWidget(_app(service));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeLocalRecordStore store;
  late _QueueClient client;
  late OfflineSyncService service;

  Future<void> seed() async {
    await _queue(store, 'm-office',
        target: 'asoud_erp.api.v1.setup.save_office',
        attempts: 2,
        extra: {'company_name': 'دفتر نمونه'});
    await _queue(store, 'm-party',
        target: 'asoud_erp.api.v1.party.save_party',
        recordId: 'PARTY-1',
        status: LocalSyncStatus.syncFailed,
        attempts: 1);
    await store.setStatus('m-party', LocalSyncStatus.syncFailed,
        error: 'نام تکراری است', attempts: 1);
    await _queue(store, 'm-unknown',
        target: 'asoud_erp.api.v1.unknown.mystery_operation');
  }

  setUp(() {
    store = FakeLocalRecordStore();
    client = _QueueClient();
    service = OfflineSyncService(client, local: store);
  });

  testWidgets('صف هر سه نوشته را با برچسب، زمان جلالی و وضعیتش نشان می‌دهد',
      (tester) async {
    await seed();
    await _pump(tester, service);

    expect(find.text('صف ارسال به سرور'), findsOneWidget);
    expect(find.text('ذخیره دفتر کار'), findsOneWidget);
    expect(find.text('ذخیره طرف حساب'), findsOneWidget);
    expect(
        find.text('asoud_erp.api.v1.unknown.mystery_operation'), findsOneWidget,
        reason: 'برچسب ناشناخته باید به نام متد بیفتد');
    expect(find.text(_createdLabel), findsNWidgets(3));
    expect(find.text('در انتظار اتصال'), findsNWidgets(2));
    expect(find.text('ناموفق: نام تکراری است'), findsOneWidget);
    expect(find.text('تلاش‌ها: ۲'), findsOneWidget);
    expect(find.text('تلاش‌ها: ۱'), findsOneWidget);
    expect(find.text('تلاش‌ها: ۰'), findsOneWidget);
    expect(find.text('۳ نوشته در انتظار ارسال به سرور است'), findsOneWidget);
    expect(find.text('همه داده‌ها ارسال شده'), findsNothing);
    expect(client.replays, isEmpty);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('صف ارسال در عرض $width بدون سرریز چیده می‌شود',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await seed();
      await _pump(tester, service);

      expect(find.text('ارسال دوباره همه'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsNWidgets(3));
      expect(find.text('حذف از صف'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('«تلاش دوباره» فقط همان ردیف را می‌فرستد', (tester) async {
    await seed();
    await _pump(tester, service);

    await tester.tap(find.text('تلاش دوباره').at(1));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(client.replays, ['m-party']);
    expect(find.text('ناموفق: نام تکراری است'), findsNothing);
    expect(find.text('ذخیره دفتر کار'), findsOneWidget);
    expect(find.text('۲ نوشته در انتظار ارسال به سرور است'), findsOneWidget);
  });

  testWidgets('«حذف از صف» پیش از حذف، هشدار برگشت‌ناپذیری می‌دهد',
      (tester) async {
    await seed();
    await _pump(tester, service);

    await tester.tap(find.text('حذف از صف').first);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(
        find.text(
            'این نوشته از صف ارسال حذف می‌شود و دیگر به سرور ارسال نخواهد شد. تا چند لحظه می‌توانید آن را بازگردانید.'),
        findsOneWidget);

    await tester.tap(find.text('انصراف'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('ذخیره طرف حساب'), findsOneWidget,
        reason: 'انصراف نباید چیزی را حذف کند');
  });

  testWidgets('تأیید «حذف از صف» ردیف و پیش‌نویس آینه‌ای را پاک می‌کند',
      (tester) async {
    await _queue(store, 'm-office',
        target: 'asoud_erp.api.v1.setup.save_office',
        status: LocalSyncStatus.syncFailed,
        extra: {'company_name': 'دفتر نمونه'});
    await store.setStatus('m-office', LocalSyncStatus.syncFailed,
        error: 'نام تکراری است');
    await store.save(
      id: 'office:sample',
      entityType: 'office',
      payload: const {'company': 'دفتر نمونه'},
      status: LocalSyncStatus.pendingSync,
    );
    await _pump(tester, service);

    await tester.tap(find.text('حذف از صف').first);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('حذف می‌کنم'));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(store.records.keys, isEmpty,
        reason: 'هم ردیف صف و هم پیش‌نویس محلی باید بروند');
    expect(find.text('همه داده‌ها ارسال شده'), findsOneWidget);
    expect(find.text('هیچ نوشته‌ای روی این گوشی منتظر ارسال به سرور نیست.'),
        findsOneWidget);
  });

  testWidgets('«ارسال همه» ردیف‌های در مهلت-backoff را هم می‌فرستد',
      (tester) async {
    await _queue(store, 'm-future',
        target: 'asoud_erp.api.v1.party.save_party',
        recordId: 'PARTY-9',
        attempts: 4,
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 30)));
    await _pump(tester, service);
    expect(find.text('مهلت تلاش بعدی: ۱۴۰۵'), findsNothing);

    await tester.tap(find.text('ارسال دوباره همه'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(client.replays, ['m-future'],
        reason: 'ارسال دستی باید مهلت و شمارش را از نو بسازد');
    expect(find.text('همه داده‌ها ارسال شده'), findsOneWidget);
  });

  testWidgets('«ارسال همه» پس از شکست، شمارش را از ۱ دوباره می‌سازد',
      (tester) async {
    await _queue(store, 'm-future',
        target: 'asoud_erp.api.v1.party.save_party',
        recordId: 'PARTY-9',
        attempts: 4,
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 30)));
    client.failure = const ApiException(
      kind: ApiFailureKind.server,
      message: 'خطای داخلی سرور',
      statusCode: 500,
    );
    await _pump(tester, service);

    await tester.tap(find.text('ارسال دوباره همه'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(store.records['m-future']?.attempts, 1,
        reason: 'شمارش باید از صفر شروع شود، نه از ۴ تای قبلی');
    expect(store.records['m-future']?.nextAttemptAt, isNotNull);
    expect(find.text('تلاش‌ها: ۱'), findsOneWidget);
  });

  testWidgets('«ارسال همه» همه ردیف‌ها را می‌فرستد', (tester) async {
    await seed();
    await _pump(tester, service);

    await tester.tap(find.text('ارسال دوباره همه'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(client.replays, ['m-office', 'm-party', 'm-unknown']);
    expect(find.text('همه داده‌ها ارسال شده'), findsOneWidget);
    expect(find.text('ارسال دوباره همه'), findsNothing);
    expect(await service.unsentCount(), 0);
  });

  testWidgets('در عرض 320 پیکسل، متن خلاصه و دکمه ارسال دوباره همه در یک ستون بدون سرریز است',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = FakeLocalRecordStore();
    final svc = OfflineSyncService(client, local: store);
    await store.save(
        id: 'a',
        entityType: 'asoud_erp.api.v1.setup.save_office',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
          'company_name': 'الف',
        },
        status: LocalSyncStatus.pendingSync);
    await store.save(
        id: 'b',
        entityType: 'asoud_erp.api.v1.party.save_party',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
          'name': 'ب',
        },
        status: LocalSyncStatus.syncFailed);

    await _pump(tester, svc);

    expect(find.byType(SyncQueueItemCard), findsNWidgets(2));
    expect(find.textContaining('نوشته در انتظار'), findsOneWidget);
    expect(find.text('ارسال دوباره همه'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('در عرض 320 پیکسل، دکمه‌ها در کارت‌ها برش نمی‌خورند', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = FakeLocalRecordStore();
    final svc = OfflineSyncService(client, local: store);
    await store.save(
        id: 'a',
        entityType: 'asoud_erp.api.v1.setup.save_office',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
          'company_name': 'الف',
        },
        status: LocalSyncStatus.pendingSync);

    await _pump(tester, svc);
    await tester.pumpAndSettle();

    final retry = find.widgetWithText(OutlinedButton, 'تلاش دوباره');
    final del = find.widgetWithText(OutlinedButton, 'حذف از صف');
    expect(retry, findsOneWidget);
    expect(del, findsOneWidget);

    final bounds = tester.getRect(find.byType(SyncQueueItemCard));
    final retryR = tester.getRect(retry);
    final delR = tester.getRect(del);
    expect(bounds.contains(retryR.topLeft), true);
    expect(bounds.contains(retryR.bottomRight), true);
    expect(bounds.contains(delR.topLeft), true);
    expect(bounds.contains(delR.bottomRight), true);
  });
}
