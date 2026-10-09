import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/request_demo_source.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';
import 'request_fixtures.dart';

/// A client whose answers the test scripts: `asoud` for `callAsoudMethod`
/// (the mutation queue and read-only calls) and `raw` for `callMethod`.
class _Client extends Fake implements FrappeApiClient {
  _Client({this.authenticated = true});
  bool authenticated;
  final asoudCalls = <({String method, Map<String, dynamic> data})>[];
  final rawCalls = <({String method, Map<String, dynamic> data})>[];
  Future<dynamic> Function(String method, Map<String, dynamic> data)? asoud;
  Future<Map<String, dynamic>> Function(
      String method, Map<String, dynamic> data)? raw;

  @override
  bool get isAuthenticated => authenticated;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
      userId: 'sara@x', fullName: 'سارا محمدی', roles: const ['Employee']);

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    final short = method.split('.').last;
    asoudCalls.add((method: short, data: Map.of(data ?? {})));
    return asoud!(short, Map.of(data ?? {}));
  }

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    final short = method.split('.').last;
    rawCalls.add((method: short, data: Map.of(data ?? {})));
    return raw!(short, Map.of(data ?? {}));
  }
}

const _offline = ApiException(kind: ApiFailureKind.network, message: 'offline');

Map<String, dynamic> _created(String name) => {
      'message': {
        'ok': true,
        'meta': {'api_version': 'v1'},
        'data': {
          ...Map<String, dynamic>.from(
              requestData('get_request_purchase') as Map),
          'name': name,
          'number': name,
        },
      },
    };

void main() {
  late _Client client;
  late FakeLocalRecordStore store;
  late GenericRequestRepository repo;

  setUp(() {
    client = _Client();
    store = FakeLocalRecordStore();
    repo = GenericRequestRepository(client, 'Wind Power LLC', store: store);
    RequestDemoRegistry.clear();
  });
  tearDown(() {
    repo.dispose();
    RequestDemoRegistry.clear();
  });

  group('listPage', () {
    test('parses rows and meta.counts, and sends the filters', () async {
      client.raw = (method, data) async => method == 'list_my_requests'
          ? requestEnvelope('list_pending')
          : throw StateError(method);
      final page = await repo.listPage(
          templateKey: 'purchase',
          statusGroup: 'pending',
          search: ' کابل ',
          priority: 'High',
          dateFrom: '2026-10-01',
          dateTo: '2026-10-31',
          offset: 0,
          limit: 20);
      expect(page.items.map((row) => row.number),
          ['PR-1405-0023', 'PR-1405-0021']);
      expect(page.items.first.statusKey, RequestStatusKey.submitted);
      expect(page.total, 2);
      expect(
          page.counts, {'all': 4, 'pending': 2, 'approved': 1, 'rejected': 1});
      expect(page.count('approved'), 1);
      final sent = client.rawCalls.single.data;
      expect(sent, {
        'company': 'Wind Power LLC',
        'template_key': 'purchase',
        'status_group': 'pending',
        'search': 'کابل',
        'priority': 'High',
        'date_from': '2026-10-01',
        'date_to': '2026-10-31',
        'limit_start': 0,
        'limit_page_length': 20,
      });
    });

    test('the tab filters are sent and defaults are omitted', () async {
      client.raw = (method, data) async => requestEnvelope('list_all');
      await repo.listPage();
      expect(client.rawCalls.last.data, {
        'company': 'Wind Power LLC',
        'status_group': 'all',
        'limit_start': 0,
        'limit_page_length': 20,
      });
      for (final group in ['approved', 'rejected']) {
        await repo.listPage(statusGroup: group, offset: 20);
        expect(client.rawCalls.last.data['status_group'], group);
        expect(client.rawCalls.last.data['limit_start'], 20);
      }
    });

    test('outbox rows come first on the first page and are counted', () async {
      client.raw = (method, data) async {
        if (method == 'create_request') throw _offline;
        return requestEnvelope('list_all');
      };
      await repo.create({
        'template_key': 'purchase',
        'subject': 'خرید کابل',
        'priority': 'High',
        'values': {
          'items': [
            {'item_code': 'CABLE-5M', 'qty': 2}
          ]
        },
        'attachments': const [],
      }, 'request-queued-0001');
      final page = await repo.listPage();
      expect(page.items.first.subject, 'خرید کابل');
      expect(page.items.first.pendingSync, isTrue);
      expect(page.items.first.statusGroup, 'pending');
      expect(page.items.first.templateKey, 'purchase');
      expect(page.items.first.itemCount, 1);
      expect(page.items.length, 5);
      expect(page.total, 5);
      expect(page.localCount, 1);
      expect(
          page.counts, {'all': 5, 'pending': 3, 'approved': 1, 'rejected': 1});

      // Only the pending tab, the template and the search match it.
      final approved = await repo.listPage(statusGroup: 'approved');
      expect(approved.items.any((row) => row.pendingSync), isFalse);
      expect(approved.counts['pending'], 3, reason: 'counts ignore the tab');
      final other = await repo.listPage(templateKey: 'leave');
      expect(other.items.any((row) => row.pendingSync), isFalse);
      final match = await repo.listPage(search: 'کابل');
      expect(match.items.any((row) => row.pendingSync), isTrue);
      final miss = await repo.listPage(search: 'zzz');
      expect(miss.items.any((row) => row.pendingSync), isFalse);
      // Later pages are the server's rows only.
      final second = await repo.listPage(offset: 20);
      expect(second.items.any((row) => row.pendingSync), isFalse);
    });

    test('a synced outbox request the list does not have yet is shown once',
        () async {
      var phase = 0;
      client.raw = (method, data) async {
        if (method == 'create_request') return _created('PR-1405-0099');
        phase++;
        return requestEnvelope('list_pending');
      };
      final result = await repo.create({
        'template_key': 'purchase',
        'subject': 'تازه',
        'values': const {},
        'attachments': const [],
      }, 'request-synced-0001');
      expect(result!['name'], 'PR-1405-0099');
      final page = await repo.listPage();
      expect(page.items.first.name, 'PR-1405-0099');
      expect(
          page.items.where((row) => row.name == 'PR-1405-0099'), hasLength(1));
      expect(page.items.first.pendingSync, isFalse);
      expect(phase, greaterThan(0));
    });

    test('offline it falls back to the cached page', () async {
      var online = true;
      client.raw = (method, data) async {
        if (!online) throw _offline;
        return requestEnvelope('list_all');
      };
      final first = await repo.listPage();
      online = false;
      final cached = await repo.listPage();
      expect(cached.items.length, first.items.length);
      expect(cached.counts, first.counts);
      expect(cached.total, 4);
    });

    test('offline without a cache lists the outbox only', () async {
      client.raw = (method, data) async => throw _offline;
      await repo.create({
        'template_key': 'leave',
        'values': const {},
        'attachments': const [],
      }, 'request-offline-0001');
      final page = await repo.listPage();
      expect(page.items.single.pendingSync, isTrue);
      expect(page.counts['all'], 1);
    });

    test('a forbidden answer is not hidden by the cache', () async {
      var allowed = true;
      client.raw = (method, data) async {
        if (!allowed) {
          throw const ApiException(
              kind: ApiFailureKind.forbidden, message: 'denied');
        }
        return requestEnvelope('list_all');
      };
      await repo.listPage();
      allowed = false;
      await expectLater(repo.listPage(), throwsA(isA<ApiException>()));
    });

    test('an answer without the v1 meta is a protocol error', () async {
      client.raw = (method, data) async => {
            'message': {'ok': true, 'data': <dynamic>[]}
          };
      await expectLater(repo.listPage(), throwsA(isA<ApiException>()));
    });
  });

  group('create', () {
    test('keeps the create_request arguments and the UI hints apart', () async {
      client.asoud = (method, data) async => method == 'request_options'
          ? requestFixture('request_options')
          : <dynamic>[];
      client.raw = (method, data) async => throw _offline;
      await repo.options(); // cached
      final data = {
        'template_key': 'purchase',
        'subject': 'خرید تجهیزات ICU',
        'values': {'priority': 'High'},
        'attachments': [
          {'filename': 'a.pdf', 'content_base64': 'YWJj', 'ref': 'att-1'}
        ],
      };
      await repo.create(data, 'request-0000000001');
      final row =
          (await store.list(entityType: 'generic_request_outbox')).single;
      expect(row.payload['data'], {
        ...data,
        'company': 'Wind Power LLC',
        'request_id': 'request-0000000001',
      });
      expect(row.payload['ui'], {
        'template_key': 'purchase',
        'request_type_title': 'درخواست خرید کالا',
        'subject': 'خرید تجهیزات ICU',
      });
      expect((row.payload['data'] as Map).containsKey('ui'), isFalse);
      // The replay sent exactly the API arguments, with template_key.
      final sent = client.rawCalls.where((c) => c.method == 'create_request');
      expect(sent.single.data['template_key'], 'purchase');
      expect(sent.single.data.containsKey('ui'), isFalse);
    });

    test('a business error on replay is stored as the readable message',
        () async {
      client.raw = (method, data) async {
        if (method != 'create_request') return requestEnvelope('list_all');
        throw const ApiException(
            kind: ApiFailureKind.validation,
            statusCode: 417,
            message: 'مانده مرخصی کافی نیست.',
            code: 'INSUFFICIENT_LEAVE_BALANCE');
      };
      await repo.create({
        'template_key': 'leave',
        'values': const {},
        'attachments': const [],
      }, 'request-0000000002');
      final row =
          (await store.list(entityType: 'generic_request_outbox')).single;
      expect(row.status, LocalSyncStatus.syncFailed);
      expect(row.lastError, 'مانده مرخصی کافی نیست.');
      final page = await repo.listPage();
      final summary = page.items.first;
      expect(summary.statusKey, RequestStatusKey.failed);
      expect(summary.statusLabel, 'نیازمند بررسی');
      expect(summary.raw['error'], 'مانده مرخصی کافی نیست.');
      expect(summary.statusGroup, 'pending');
    });
  });

  group('comments', () {
    test('lists the thread', () async {
      client.asoud = (method, data) async => method == 'list_request_comments'
          ? requestData('list_comments')
          : throw StateError(method);
      final comments = await repo.comments('PR-1405-0023');
      expect(comments.single.content, 'لطفاً پیش‌فاکتور را پیوست کنید.');
      expect(comments.single.authorName, 'احمد رضایی');
      expect(comments.single.isMine, isFalse);
      expect(client.asoudCalls.single.data, {'name': 'PR-1405-0023'});
    });

    test('adding online returns the server comment', () async {
      client.asoud = (method, data) async => method == 'add_request_comment'
          ? requestData('add_comment')
          : throw StateError(method);
      final comment =
          await repo.addComment('PR-1405-0023', '  پیش‌فاکتور پیوست شد.  ');
      expect(comment.name, 'abc124');
      expect(comment.pending, isFalse);
      expect(client.asoudCalls.single.data,
          {'name': 'PR-1405-0023', 'content': 'پیش‌فاکتور پیوست شد.'});
    });

    test('an empty comment is refused without a call', () async {
      client.asoud = (method, data) async => throw StateError(method);
      await expectLater(
          repo.addComment('PR-1', '   '), throwsA(isA<ApiException>()));
      expect(client.asoudCalls, isEmpty);
    });

    test('offline it becomes a pending comment that stays in the thread',
        () async {
      var online = false;
      client.asoud = (method, data) async {
        if (method == 'add_request_comment') {
          throw const QueuedOfflineException(localId: 'q1');
        }
        if (!online) throw _offline;
        return requestData('list_comments');
      };
      final comment = await repo.addComment('PR-1405-0023', 'پس از اتصال');
      expect(comment.pending, isTrue);
      expect(comment.isMine, isTrue);
      expect(comment.content, 'پس از اتصال');

      online = true;
      final thread = await repo.comments('PR-1405-0023');
      expect(thread.map((c) => c.content),
          ['لطفاً پیش‌فاکتور را پیوست کنید.', 'پس از اتصال']);
      expect(thread.last.pending, isTrue);
      // Another request's thread does not show it.
      expect((await repo.comments('PR-OTHER')).any((c) => c.pending), isFalse);

      // Once the queue delivered it the server list has it and the local copy
      // is dropped.
      client.asoud = (method, data) async => [
            ...(requestData('list_comments') as List),
            {
              'name': 'zz',
              'content': 'پس از اتصال',
              'author': 'sara@x',
              'author_name': 'سارا محمدی',
              'creation': '2026-10-06 09:00:00',
              'is_mine': true
            }
          ];
      final delivered = await repo.comments('PR-1405-0023');
      expect(delivered, hasLength(2));
      expect(delivered.any((c) => c.pending), isFalse);
      expect(await store.list(entityType: 'generic_request_comment_pending'),
          isEmpty);
    });

    test('a timeout is queued too', () async {
      client.asoud = (method, data) async => throw TimeoutException('slow');
      final comment = await repo.addComment('PR-1', 'سلام');
      expect(comment.pending, isTrue);
    });

    test('a refusal is not turned into a pending comment', () async {
      client.asoud = (method, data) async => throw const ApiException(
          kind: ApiFailureKind.forbidden, message: 'denied');
      await expectLater(
          repo.addComment('PR-1', 'سلام'), throwsA(isA<ApiException>()));
      expect(await store.list(entityType: 'generic_request_comment_pending'),
          isEmpty);
    });
  });

  group('update and cancel', () {
    test('send new and removed files only when there are some', () async {
      client.asoud = (method, data) async => {'name': 'PR-1', 'subject': 'x'};
      await repo.update('PR-1', 'x', {'reason': 'y'});
      expect(client.asoudCalls.last.data, {
        'name': 'PR-1',
        'subject': 'x',
        'values': {'reason': 'y'}
      });
      await repo.update('PR-1', 'x', {
        'reason': 'y'
      }, attachments: [
        {'filename': 'a.pdf', 'content_base64': 'YWJj', 'ref': 'att-1'}
      ], removeAttachments: [
        '1a2b3c'
      ]);
      expect(client.asoudCalls.last.method, 'update_request');
      expect(client.asoudCalls.last.data['attachments'], [
        {'filename': 'a.pdf', 'content_base64': 'YWJj', 'ref': 'att-1'}
      ]);
      expect(client.asoudCalls.last.data['remove_attachments'], ['1a2b3c']);
    });

    test('offline the saved message is shown', () async {
      client.asoud = (method, data) async =>
          throw const QueuedOfflineException(localId: 'q2');
      await expectLater(
          repo.update('PR-1', 'x', {}, attachments: [
            {'filename': 'a.pdf', 'content_base64': 'YWJj', 'ref': 'att-1'}
          ]),
          throwsA(isA<QueuedOfflineException>().having((e) => e.message,
              'message', 'ذخیره شد؛ پس از اتصال ارسال می‌شود')));
      await expectLater(repo.cancel('PR-1', reason: 'x'),
          throwsA(isA<QueuedOfflineException>()));
    });
  });

  group('leave and attachments', () {
    test('leaveBalance and previewLeave read the leave module', () async {
      client.asoud = (method, data) async => switch (method) {
            'get_leave_balance' => requestData('leave_balance'),
            'preview_leave_request' =>
              requestData('preview_leave_insufficient'),
            _ => throw StateError(method),
          };
      final balance = await repo.leaveBalance();
      expect(balance.category('annual')!.remainingDays, 12.5);
      final preview = await repo.previewLeave({
        'leave_type': 'Casual Leave',
        'request_kind': 'Hourly',
        'leave_date': '2026-10-06',
        'start_time': '10:00',
        'end_time': '14:00',
        'start_date': null,
        'end_date': '',
      });
      expect(preview.errors.single.code, 'INSUFFICIENT_LEAVE_BALANCE');
      expect(client.asoudCalls.first.data, {'company': 'Wind Power LLC'});
      expect(
          client.asoudCalls.last.data,
          {
            'company': 'Wind Power LLC',
            'leave_type': 'Casual Leave',
            'request_kind': 'Hourly',
            'leave_date': '2026-10-06',
            'start_time': '10:00',
            'end_time': '14:00',
          },
          reason: 'empty values are not sent');
    });

    test('the leave balance falls back to the cache offline', () async {
      var online = true;
      client.asoud = (method, data) async {
        if (!online) throw _offline;
        return requestData('leave_balance');
      };
      await repo.leaveBalance();
      online = false;
      expect((await repo.leaveBalance()).employee, 'HR-EMP-00001');
    });

    test('attachment asks for a thumbnail only when told to', () async {
      client.asoud = (method, data) async => requestData('get_attachment');
      final thumb = await repo.attachment('1a2b3c', thumbnail: true);
      expect(client.asoudCalls.last.data, {'name': '1a2b3c', 'thumbnail': 1});
      expect(thumb.filename, 'm.png');
      expect(thumb.contentType, 'image/png');
      expect(thumb.bytes, isNotEmpty);
      final full = await repo.attachment('1a2b3c');
      expect(client.asoudCalls.last.data, {'name': '1a2b3c'});
      expect(full.bytes, thumb.bytes);
      // A file that is not an image answer is a protocol error.
      client.asoud = (method, data) async => {'filename': 'x'};
      await expectLater(repo.attachment('x'), throwsA(isA<ApiException>()));
    });

    test('fieldOptions passes the scope', () async {
      client.asoud = (method, data) async => <dynamic>[];
      await repo.fieldOptions('Item', txt: 'مان', scope: 'purchase');
      expect(client.asoudCalls.last.data, {
        'company': 'Wind Power LLC',
        'field_type': 'Item',
        'txt': 'مان',
        'scope': 'purchase',
      });
      await repo.fieldOptions('UOM', itemCode: 'ICU-MON-01');
      expect(client.asoudCalls.last.data.containsKey('scope'), isFalse);
      expect(client.asoudCalls.last.data['item_code'], 'ICU-MON-01');
    });
  });

  group('offline preview (no session)', () {
    late _Client local;
    late GenericRequestRepository preview;
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      local = _Client(authenticated: false);
      preview =
          GenericRequestRepository(local, 'شرکت نمونه آسود', store: store);
    });
    tearDown(() => preview.dispose());

    test('every request method has a local implementation', () async {
      expect(preview.isLocal, isTrue);
      final page = await preview.listPage();
      expect(page.items, isNotEmpty);
      expect(page.counts['all'], page.items.length);
      final pending = await preview.listPage(statusGroup: 'pending');
      expect(
          pending.items.every((row) => row.statusGroup == 'pending'), isTrue);
      expect(pending.counts['all'], page.counts['all']);
      expect((await preview.leaveBalance()).category('annual')!.remainingDays,
          12.5);
      expect((await preview.leaveBalance()).category('sick')!.remainingDays, 8);
      expect(
          (await preview.leaveBalance()).category('other')!.remainingDays, 2);
      final file = await preview.attachment('DEMO-FILE-1', thumbnail: true);
      expect(file.bytes, isNotEmpty);
      expect(local.asoudCalls, isEmpty);
      expect(local.rawCalls, isEmpty);
    });

    test('local comments are stored on the device and are not pending',
        () async {
      final comment = await preview.addComment('DEMO-REQ-003', 'یک نظر محلی');
      expect(comment.pending, isFalse);
      expect(comment.isMine, isTrue);
      final thread = await preview.comments('DEMO-REQ-003');
      expect(thread.map((c) => c.content), contains('یک نظر محلی'));
      expect((await preview.comments('DEMO-REQ-004')).map((c) => c.content),
          isNot(contains('یک نظر محلی')));
      expect((await preview.detail('DEMO-REQ-003'))['comment_count'], 1);
    });

    test('sample rows cannot be edited or cancelled', () async {
      expect(preview.isSampleRequest('DEMO-REQ-003'), isTrue);
      expect(preview.isSampleRequest('generic-request:x'), isFalse);
      await expectLater(
          preview.update('DEMO-REQ-003', 'x', {}),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('درخواست نمایشی قابل ویرایش نیست'))));
      await expectLater(
          preview.cancel('DEMO-REQ-003'),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('درخواست نمایشی قابل لغو نیست'))));
      expect(local.asoudCalls, isEmpty);
    });

    test('a created request is local_preview and listed first', () async {
      final created = await preview.create({
        'template_key': 'purchase',
        'subject': 'درخواست محلی',
        'values': const {},
        'attachments': const [],
      }, 'request-local-0001');
      expect(created!['local_preview'], isTrue);
      expect(created['can_edit'], isFalse);
      final page = await preview.listPage();
      expect(page.items.first.subject, 'درخواست محلی');
      expect(page.items.first.localPreview, isTrue);
      expect(page.items.first.number, startsWith('LOCAL-'));
      expect(page.counts['pending'],
          (await preview.listPage(statusGroup: 'pending')).items.length);
      final search = await preview.listPage(search: 'محلی');
      expect(search.items.single.subject, 'درخواست محلی');
      await expectLater(
          preview.update('${created['name']}', 'x', {}), throwsStateError);
    });

    test('registered demo sources feed types, rows, comments and masters',
        () async {
      RequestDemoRegistry.register(_Source());
      final types = await preview.options();
      expect(types.first['name'], 'SYS-DEMO');
      final page = await preview.listPage(templateKey: 'leave');
      expect(page.items.map((row) => row.number), ['LV-1404-0042']);
      expect(page.items.single.summary['duration']['unit'], 'day');
      expect(page.counts['approved'], 1);
      final detail = await preview.detail('LV-1404-0042');
      expect(detail['can_edit'], isFalse);
      expect(detail['values']['reason'], 'سفر');
      expect(
          (await preview.comments('LV-1404-0042')).single.content, 'تأیید شد');
      expect((await preview.fieldOptions('Leave Type')).map((r) => r['value']),
          ['Special Leave']);
      expect((await preview.fieldOptions('Cost Center')).map((r) => r['value']),
          contains('MED - DEMO'),
          reason: 'types the source does not define keep the built-in samples');
      expect(
          (await preview.fieldOptions('Item', scope: 'purchase'))
              .map((r) => r['value']),
          isNot(contains('SVC-INSTALL')),
          reason: 'service items are not purchase items');
      expect((await preview.fieldOptions('Item')).map((r) => r['value']),
          contains('SVC-INSTALL'));
    });

    test('the local leave preview mirrors the server rules', () async {
      Future<LeavePreview> run(Map<String, dynamic> args) =>
          preview.previewLeave({'leave_type': 'Casual Leave', ...args});
      // 2026-10-09 is a Friday (the weekend), 10 and 11 are Saturday, Sunday.
      var result = await run({
        'request_kind': 'Daily',
        'start_date': '2026-10-10',
        'end_date': '2026-10-12'
      });
      expect(result.valid, isTrue);
      expect(result.duration.label, '۳ روز');
      expect(result.balance!.remainingAfter, 9.5);
      result = await run({
        'request_kind': 'Daily',
        'start_date': '2026-10-09',
        'end_date': '2026-10-12'
      });
      expect(result.duration.days, 3, reason: 'Friday is not counted');
      expect(result.holidaysExcluded, 1);
      result = await run({
        'request_kind': 'Daily',
        'start_date': '2026-10-09',
        'end_date': '2026-10-09'
      });
      expect(result.errors.single.code, 'LEAVE_ALL_HOLIDAYS');
      result = await run({
        'request_kind': 'Daily',
        'start_date': '2026-10-12',
        'end_date': '2026-10-10'
      });
      expect(result.errors.single.code, 'INVALID_DATE_RANGE');
      result = await run({
        'request_kind': 'Daily',
        'start_date': '2026-10-10',
        'end_date': '2026-11-20'
      });
      expect(result.valid, isFalse);
      expect(result.errors.single.code, 'INSUFFICIENT_LEAVE_BALANCE');
      expect(result.errors.single.field, 'leave_type');

      result = await run({
        'request_kind': 'Hourly',
        'leave_date': '2026-10-10',
        'start_time': '10:00',
        'end_time': '14:00'
      });
      expect(result.valid, isTrue);
      expect(result.duration.label, '۴ ساعت');
      expect(result.duration.dayEquivalent, 0.5);
      expect(result.balance!.remainingAfter, 12.0);
      result = await run({
        'request_kind': 'Hourly',
        'leave_date': '2026-10-10',
        'start_time': '10:00',
        'end_time': '11:30'
      });
      expect(result.duration.label, '۱٫۵ ساعت');
      for (final (args, code) in [
        ({'start_time': '14:00', 'end_time': '10:00'}, 'INVALID_TIME_RANGE'),
        ({'start_time': '10:00', 'end_time': '10:10'}, 'INVALID_TIME_RANGE'),
        ({'start_time': '08:00', 'end_time': '17:00'}, 'HOURLY_EXCEEDS_DAY'),
        (
          {
            'leave_date': '2026-10-09',
            'start_time': '10:00',
            'end_time': '12:00'
          },
          'HOURLY_ON_HOLIDAY'
        ),
      ]) {
        result = await run({
          'request_kind': 'Hourly',
          'leave_date': '2026-10-10',
          ...args,
        });
        expect(result.errors.map((e) => e.code), contains(code), reason: code);
        expect(result.valid, isFalse);
      }
      // The 15-minute minimum uses the contract code, with its own message.
      result = await run({
        'request_kind': 'Hourly',
        'leave_date': '2026-10-10',
        'start_time': '10:00',
        'end_time': '10:10'
      });
      expect(result.errors.single.code, 'INVALID_TIME_RANGE');
      expect(
          result.errors.single.message, 'حداقل مدت مرخصی ساعتی ۱۵ دقیقه است.');
      // Incomplete input is not an error, only not valid yet.
      result = await run({'request_kind': 'Hourly'});
      expect(result.valid, isFalse);
      expect(result.errors, isEmpty);
      // Leave without pay has no balance to check.
      result = await preview.previewLeave({
        'leave_type': 'Leave Without Pay',
        'request_kind': 'Daily',
        'start_date': '2026-10-10',
        'end_date': '2026-12-30'
      });
      expect(result.valid, isTrue);
      expect(result.balance, isNull);
    });
  });
}

class _Source extends RequestDemoSource {
  @override
  List<Map> requestTypes() => [
        {
          'name': 'SYS-DEMO',
          'workflow_title': 'درخواست نمونه',
          'template_key': 'leave',
          'fields': []
        }
      ];

  @override
  List<Map> requests() => [
        {
          'is_sample': true,
          'name': 'LV-1404-0042',
          'number': 'LV-1404-0042',
          'template_key': 'leave',
          'subject': 'مرخصی سالانه (روزانه)',
          'request_type': 'درخواست مرخصی',
          'status_key': 'approved',
          'status_label': 'تأیید شده',
          'status_group': 'approved',
          'creation': DateTime.now().toIso8601String(),
          'summary': {
            'duration': {'unit': 'day', 'days': 3.0}
          },
          'values': {'reason': 'سفر'},
        }
      ];

  @override
  List<Map> comments(String name) => name == 'LV-1404-0042'
      ? [
          {
            'name': 'c1',
            'content': 'تأیید شد',
            'author_name': 'احمد رضایی',
            'creation': '2026-10-05 09:00:00'
          }
        ]
      : [];

  @override
  Map<String, List<Map>> fieldOptions() => {
        'Leave Type': [
          {'value': 'Special Leave', 'label': 'ویژه', 'category': 'other'}
        ]
      };
}
