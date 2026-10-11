import 'dart:convert';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/sync_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

const _server = 'injected-client';

String _requestScope(
        {String server = _server,
        String owner = 'user',
        String company = 'office'}) =>
    jsonEncode([server, owner, company]);

Future<void> _stageRequest(
  FakeLocalRecordStore store,
  String id, {
  String owner = 'user',
  String server = _server,
  String company = 'office',
  String subject = 'درخواست مرخصی',
  LocalSyncStatus status = LocalSyncStatus.pendingSync,
  String? error,
  DateTime? createdAt,
}) async {
  await store.save(
    id: id,
    entityType: 'generic_request_outbox',
    payload: {
      'scope': _requestScope(server: server, owner: owner, company: company),
      'data': {
        'company': company,
        'request_id': id,
        'subject': subject,
        'template_key': 'leave',
      },
      'ui': {
        'subject': subject,
        'template_key': 'leave',
        'request_type_title': 'درخواست مرخصی',
      },
    },
    status: status,
    createdAt: createdAt,
  );
  if (error != null) {
    await store.setStatus(id, status, error: error);
  }
}

Future<void> _stageMutation(FakeLocalRecordStore store, String id,
        {String owner = 'user', DateTime? createdAt}) =>
    store.save(
      id: id,
      entityType: 'asoud_erp.api.v1.party.save_party',
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': owner,
        '_asoud_server': _server,
        'name': 'PARTY-$id',
      },
      status: LocalSyncStatus.pendingSync,
      createdAt: createdAt,
    );

class _OwnerClient implements FrappeApiClient {
  _OwnerClient({required this.userId});

  final String userId;
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

void main() {
  test('صف یک درخواست آفلاین و یک نوشته معمولی را با هم فهرست و شمارش می‌کند',
      () async {
    final store = FakeLocalRecordStore();
    final service = OfflineSyncService(_OwnerClient(userId: 'user'),
        local: store);
    final old = DateTime(2026, 3, 20, 10);
    final newer = old.add(const Duration(minutes: 5));

    await _stageRequest(store, 'req-1', company: 'دفتر نمونه', createdAt: old);
    await _stageMutation(store, 'm-1', createdAt: newer);

    expect((await service.unsent()).map((row) => row.id), ['req-1', 'm-1']);
    expect(await service.unsentCount(), 2,
        reason: 'درخواست آفلاین و نوشته معمولی باید هر دو در نوار/صفحهٔ صف بیایند');
  });

  test('حذف درخواست فقط همان ردیف را برمی‌دارد و بازگردانی آن را برمی‌گرداند',
      () async {
    final store = FakeLocalRecordStore();
    final service = OfflineSyncService(_OwnerClient(userId: 'user'),
        local: store);

    await _stageRequest(store, 'req-1', company: 'دفتر نمونه');
    await _stageMutation(store, 'm-1');

    final removed = await service.discardReturning('req-1');

    expect(removed.map((row) => row.id), ['req-1']);
    expect(store.records.containsKey('req-1'), isFalse,
        reason: 'فقط درخواست باید حذف شود');
    expect(store.records.containsKey('m-1'), isTrue);
    expect(await service.unsentCount(), 1);

    await service.restore(removed);

    expect(store.records.containsKey('req-1'), isTrue,
        reason: 'بازگردانی باید ردیف حذف‌شده را همان‌گونه برگرداند');
    expect(await service.unsentCount(), 2);
  });

  test('درخواست کاربر دیگر نه در صف دیده می‌شود و نه حذف می‌پذیرد', () async {
    final store = FakeLocalRecordStore();
    final service = OfflineSyncService(_OwnerClient(userId: 'user'),
        local: store);

    await _stageRequest(store, 'req-other', owner: 'someone-else');

    expect(await service.unsent(), isEmpty,
        reason: 'درخواست کاربر دیگر نباید در صف کاربر جاری دیده شود');
    expect(await service.unsentCount(), 0);

    await service.discardReturning('req-other');

    expect(store.records.containsKey('req-other'), isTrue,
        reason: 'حذف نباید به ردیف کاربر دیگر دست بزند');
  });

  test('تلاش دوبارهٔ درخواست، مسیر همگام‌سازی مخزن را یک بار برای همان دفتر صدا می‌زند',
      () async {
    final store = FakeLocalRecordStore();
    final calls = <({String company, bool retry})>[];
    final service = OfflineSyncService(_OwnerClient(userId: 'user'),
        local: store, syncRequests: (company, {required retry}) async {
      calls.add((company: company, retry: retry));
    });

    await _stageRequest(store, 'req-1', company: 'دفتر نمونه');
    await _stageRequest(store, 'req-2', company: 'دفتر نمونه');
    await _stageMutation(store, 'm-1');

    await service.retry('req-1');

    expect(calls, [(company: 'دفتر نمونه', retry: true)],
        reason: 'ارسال دستی باید از مسیر sync مخزن و با بلیت retry عبور کند');
  });

  test('«ارسال دوباره همه» درخواست‌ها را هر دفتر یک بار از مسیر مخزن می‌فرستد',
      () async {
    final store = FakeLocalRecordStore();
    final calls = <({String company, bool retry})>[];
    final service = OfflineSyncService(_OwnerClient(userId: 'user'),
        local: store, syncRequests: (company, {required retry}) async {
      calls.add((company: company, retry: retry));
    });

    await _stageRequest(store, 'req-a', company: 'دفتر الف');
    await _stageRequest(store, 'req-aa', company: 'دفتر الف');
    await _stageRequest(store, 'req-b', company: 'دفتر ب');
    await _stageMutation(store, 'm-1');

    await service.retryAll();

    expect(calls, [
      (company: 'دفتر الف', retry: true),
      (company: 'دفتر ب', retry: true),
    ]);
  });

  test('شمارش unsent همگام‌سازی خودکار، درخواست در انتظار را می‌فرستد', () async {
    final store = FakeLocalRecordStore();
    final calls = <({String company, bool retry})>[];
    final client = _OwnerClient(userId: 'user');
    final service = OfflineSyncService(client,
        local: store, syncRequests: (company, {required retry}) async {
      calls.add((company: company, retry: retry));
    });

    await _stageRequest(store, 'req-1', company: 'دفتر نمونه');
    await _stageMutation(store, 'm-1');

    await service.syncNow();

    expect(calls, [(company: 'دفتر نمونه', retry: false)],
        reason: 'همگام‌سازی خودکار باید درخواست آفلاین را هم به سمت مخزن بفرستد');
  });

  testWidgets('کارت درخواست آفلاین موضوع را عنوان، «ثبت درخواست» و حالت را نشان می‌دهد',
      (tester) async {
    final store = FakeLocalRecordStore();
    final client = _OwnerClient(userId: 'user');
    final service = OfflineSyncService(client, local: store);

    await _stageRequest(store, 'generic-request:req-1',
        company: 'دفتر نمونه', subject: 'مرخصی هفتهٔ آتی');
    await _stageRequest(store, 'generic-request:req-2',
        company: 'دفتر نمونه',
        subject: 'خرید کالای اداری',
        status: LocalSyncStatus.syncFailed,
        error: 'نام تکراری است');

    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: SyncQueuePage(service: service),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('مرخصی هفتهٔ آتی'), findsOneWidget,
        reason: 'عنوان کارت باید موضوع درخواست باشد');
    expect(find.text('خرید کالای اداری'), findsOneWidget);
    expect(find.text('ثبت درخواست'), findsNWidgets(2),
        reason: 'عملیات باید به فارسی «ثبت درخواست» باشد');
    expect(find.text('در انتظار ارسال'), findsOneWidget);
    expect(find.text('ناموفق: نام تکراری است'), findsOneWidget);
    expect(find.text('۲ نوشته در انتظار ارسال به سرور است'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}