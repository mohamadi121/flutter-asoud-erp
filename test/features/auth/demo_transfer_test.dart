import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/auth/data/demo_choice_store.dart';
import 'package:asoud_erp/features/auth/data/demo_transfer_service.dart';
import 'package:asoud_erp/features/auth/data/unsent_offline_count.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';

class _NoClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async =>
      const FrappeUserContext(userId: 'user', fullName: 'کاربر آزمون', roles: []);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('demo choice is remembered across restarts', () async {
    expect(await DemoChoiceStore.isDemoChosen(), isFalse);
    await DemoChoiceStore.setDemoChosen(true);
    expect(await DemoChoiceStore.isDemoChosen(), isTrue);
    await DemoChoiceStore.setDemoChosen(false);
    expect(await DemoChoiceStore.isDemoChosen(), isFalse);
  });

  test('unsent count equals the send-queue list, in Persian digits', () async {
    final store = FakeLocalRecordStore();
    await store.save(
        id: 'p1',
        entityType: 'm',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
        },
        status: LocalSyncStatus.pendingSync);
    // A local mirror row has no operation: it is not a queued write.
    await store.save(
        id: 'mirror',
        entityType: 'office',
        payload: const {'company': 'دفتر'},
        status: LocalSyncStatus.pendingSync);
    await store.save(
        id: 'mirror-failed',
        entityType: 'office',
        payload: const {'company': 'دفتر ۲'},
        status: LocalSyncStatus.syncFailed);
    await store.save(
        id: 'f1',
        entityType: 'm',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
        },
        status: LocalSyncStatus.syncFailed);
    await store.save(
        id: 's1',
        entityType: 'm',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
        },
        status: LocalSyncStatus.synced);
    // The queue screen lists localOnly writes that carry an operation, but
    // not preview rows (no operation).
    await store.save(
        id: 'l1',
        entityType: 'm',
        payload: const {
          'operation': 'asoud_method',
          '_asoud_owner': 'user',
          '_asoud_server': 'injected-client',
        },
        status: LocalSyncStatus.localOnly);
    await store.save(
        id: 'preview',
        entityType: 'generic_request_outbox',
        payload: const {'scope': 's', 'data': {}},
        status: LocalSyncStatus.localOnly);

    final count = await countUnsentOfflineRows(store: store);

    expect(count, 3);
    expect(count,
        await OfflineSyncService(_NoClient(), local: store).unsentCount());
    expect(toPersianDigits(3), '۳');
    expect(toPersianDigits(12), '۱۲');
  });

  test('transfer list contains only user-created preview items', () async {
    final store = FakeLocalRecordStore();
    // A user-created demo request (preview owner, localOnly).
    await store.save(
      id: 'generic-request:["srv","offline-preview","c"]:request-local-1',
      entityType: 'generic_request_outbox',
      status: LocalSyncStatus.localOnly,
      payload: {
        'scope': '["srv","offline-preview","c"]',
        'data': {
          'company': 'دفتر نمونه',
          'subject': 'خرید لپ‌تاپ',
          'workflow_definition': 'SYS-PURCHASE-WP',
        },
      },
    );
    // A seeded/sample row must never be offered.
    await store.save(
      id: 'generic-request:["srv","offline-preview","c"]:request-sample',
      entityType: 'generic_request_outbox',
      status: LocalSyncStatus.localOnly,
      payload: {
        'scope': '["srv","offline-preview","c"]',
        'data': {'is_sample': true, 'subject': 'نمونه'},
      },
    );
    SharedPreferences.setMockInitialValues({
      'asoud_workflow_designs_v2':
          '[{"workflow":{"id":"PREVIEW-DRAFT-1","title":"درخواست مرخصی","target_doctype":"ASOUD Workflow Request"},"stages":[],"transitions":[]}]',
      'asoud_document_templates_local_v1':
          '[{"name":"LOCAL-TPL-1","title":"سند هزینه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active","company":"دفتر نمونه"}]',
    });

    final service = DemoTransferService(store: store);
    final items = await service.listCandidates();

    final ids = items.map((item) => item.id).toSet();
    expect(
        ids,
        containsAll([
          'generic-request:["srv","offline-preview","c"]:request-local-1',
          'PREVIEW-DRAFT-1',
          'LOCAL-TPL-1',
        ]));
    expect(ids.any((id) => id.contains('request-sample')), isFalse);
    // Built-in samples are never offered even if stored under sample ids.
    expect(ids, isNot(contains('DEMO-REQ-003')));
    expect(ids, isNot(contains('PREVIEW-WF-001')));
    // Workflow designs reference local stage ids: not safely transferable.
    final design = items.singleWhere((item) => item.id == 'PREVIEW-DRAFT-1');
    expect(design.transferable, isFalse);
    expect(design.nonTransferReason, isNotEmpty);
    // Requests and templates are transferable.
    expect(
        items
            .singleWhere((item) => item.id.endsWith('request-local-1'))
            .transferable,
        isTrue);
    expect(items.singleWhere((item) => item.id == 'LOCAL-TPL-1').transferable,
        isTrue);
  });

  test('transferring one generic request submits exactly once and removes it',
      () async {
    final store = FakeLocalRecordStore();
    const rowId =
        'generic-request:["srv","offline-preview","c"]:request-local-9';
    await store.save(
      id: rowId,
      entityType: 'generic_request_outbox',
      status: LocalSyncStatus.localOnly,
      payload: {
        'scope': '["srv","offline-preview","c"]',
        'data': {
          'company': 'دفتر نمونه',
          'subject': 'خرید لپ‌تاپ',
          'workflow_definition': 'SYS-PURCHASE-WP',
        },
      },
    );
    final service = DemoTransferService(store: store);
    final items = await service.listCandidates();
    expect(items.where((item) => item.id == rowId), hasLength(1));

    var calls = 0;
    Map<String, dynamic>? submitted;
    await service.transferGenericRequest(
        items.singleWhere((i) => i.id == rowId), submit: (data) async {
      calls++;
      submitted = data;
      return {'name': 'REQ-1'};
    });

    expect(calls, 1);
    expect(submitted!['subject'], 'خرید لپ‌تاپ');
    expect(await store.get(rowId), isNull);
    expect(await service.listCandidates(), isEmpty);
  });

  Future<DemoTransferItem> seedRequest(
    FakeLocalRecordStore store,
    DemoTransferService service,
    String rowId,
  ) async {
    await store.save(
      id: rowId,
      entityType: 'generic_request_outbox',
      status: LocalSyncStatus.localOnly,
      payload: {
        'scope': '["srv","offline-preview","c"]',
        'data': {
          'company': 'دفتر نمونه',
          'subject': 'خرید لپ‌تاپ',
          'workflow_definition': 'SYS-PURCHASE-WP',
        },
      },
    );
    return (await service.listCandidates())
        .singleWhere((item) => item.id == rowId);
  }

  test('هر بار ارسال یک ردیف نمایشی همان request_id را دارد', () async {
    final store = FakeLocalRecordStore();
    final service = DemoTransferService(store: store);
    final item = await seedRequest(store, service, 'generic-request:a:r-1');
    final other = await seedRequest(store, service, 'generic-request:a:r-2');

    final ids = <String>[];
    // The first attempt fails for a reason that does not queue the write, so
    // the preview row stays and the user taps again.
    await expectLater(
        service.transferGenericRequest(item, submit: (data) async {
          ids.add('${data['request_id']}');
          throw StateError('timeout after commit');
        }),
        throwsStateError);
    expect(await store.get(item.id), isNotNull);
    await service.transferGenericRequest(item, submit: (data) async {
      ids.add('${data['request_id']}');
    });

    expect(ids, hasLength(2));
    expect(ids.first, ids.last);
    // The server accepts request ids of 8 to 100 characters.
    expect(ids.first.length, inInclusiveRange(8, 100));
    expect(DemoTransferService.requestIdFor(other), isNot(ids.first));
  });

  test('نوشته صف‌شده خطا نیست و نسخه نمایشی درخواست پاک می‌شود', () async {
    final store = FakeLocalRecordStore();
    final service = DemoTransferService(store: store);
    final item = await seedRequest(store, service, 'generic-request:a:r-3');

    final queued = await service.transferGenericRequest(item,
        submit: (_) async => throw const QueuedOfflineException(localId: 'q'));

    expect(queued, isTrue);
    expect(await store.get(item.id), isNull);
    expect(await service.listCandidates(), isEmpty);
  });

  test('خطای دیگر نسخه نمایشی را نگه می‌دارد', () async {
    final store = FakeLocalRecordStore();
    final service = DemoTransferService(store: store);
    final item = await seedRequest(store, service, 'generic-request:a:r-4');

    await expectLater(
        service.transferGenericRequest(item,
            submit: (_) async => throw StateError('rejected')),
        throwsStateError);

    expect(await store.get(item.id), isNotNull);
  });

  test('الگوی صف‌شده خطا نیست و نسخه نمایشی الگو پاک می‌شود', () async {
    SharedPreferences.setMockInitialValues({
      'asoud_document_templates_local_v1':
          '[{"name":"LOCAL-TPL-8","title":"سند هزینه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active","company":"دفتر نمونه"}]',
    });
    final service = DemoTransferService(store: FakeLocalRecordStore());
    final item = (await service.listCandidates()).single;

    final queued = await service.transferTemplate(item,
        submit: (_) async => throw const QueuedOfflineException(localId: 'q'));

    expect(queued, isTrue);
    expect(await service.listCandidates(), isEmpty);
  });

  test('ignoring a template removes the local copy without submitting',
      () async {
    SharedPreferences.setMockInitialValues({
      'asoud_document_templates_local_v1':
          '[{"name":"LOCAL-TPL-7","title":"سند هزینه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active","company":"دفتر نمونه"}]',
    });
    final service = DemoTransferService(store: FakeLocalRecordStore());
    final items = await service.listCandidates();
    expect(items.map((item) => item.id), contains('LOCAL-TPL-7'));

    var calls = 0;
    await service.ignore(items.singleWhere((i) => i.id == 'LOCAL-TPL-7'));
    expect(calls, 0);
    expect(await service.listCandidates(), isEmpty);
  });
}
