import 'dart:async';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_record.dart';
import 'package:asoud_erp/features/hr/presentation/cubit/personnel_cubit.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

class _Repository extends Mock implements PersonnelRepository {}

void main() {
  test('financial values stay out of shared party cache including legacy entries', () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.authenticationChanges).thenAnswer((_) => const Stream.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async => const FrappeUserContext(
      userId: 'hr', fullName: 'HR', roles: ['HR Manager']));
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenAnswer((call) async {
      if ((call.positionalArguments.first as String).endsWith('list_personnel')) {
        return {'message': {'data': {'rows': [], 'can_edit': true}}};
      }
      return {'message': {'data': {'profile': {'id': 'P1', 'company': 'office',
        'base_salary': 456, 'display_name': 'Updated'}, 'can_edit': true, 'records': [], 'revision': '2'}}};
    });
    final store = FakeLocalRecordStore();
    await store.save(id: 'party:P1', entityType: 'party_profile', payload: {
      'company': 'office', 'base_salary': 123, 'display_name': 'Before'});
    final repo = PersonnelRepository(client, local: store);
    addTearDown(repo.dispose);
    await repo.list('office');
    await repo.update('P1', {'base_salary': 456}, '1');
    final shared = (await store.get('party:P1'))!.payload;
    expect(shared.containsKey('base_salary'), false);
    expect(shared['display_name'], 'Updated');
  });

  test('local import requires explicit binding, is durable and cannot be remapped', () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.authenticationChanges).thenAnswer((_) => const Stream.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async => const FrappeUserContext(
      userId: 'hr', fullName: 'HR', roles: ['HR Manager']));
    final store = FakeLocalRecordStore();
    await store.save(id: 'party:LOCAL-1', entityType: 'party_profile', payload: {
      'id': 'LOCAL-1', 'company': 'office', 'roles': ['employee'], 'display_name': 'علی',
    });
    await store.save(id: 'local-record-1', entityType: 'personnel_demo_record', payload: {
      'party': 'LOCAL-1', 'content': {'kind': 'evaluation', 'title': 'ارزیابی', 'date': '2026-09-08', 'score': 80},
    });
    final sent = <String>[];
    var online = false;
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenAnswer((invocation) async {
      final method = invocation.positionalArguments.first as String;
      final data = invocation.namedArguments[#data] as Map;
      if (method.endsWith('get_personnel')) {
        return {'message': {'data': {
        'profile': {'id': data['name'], 'company': 'office'}, 'can_edit': true, 'records': [], 'revision': '1',
      }}};
      }
      if (!online) throw const ApiException(kind: ApiFailureKind.network, message: 'offline');
      sent.add('${data['request_id']}');
      expect(data['name'], 'REMOTE-1');
      return {'message': {'data': {'id': 'record-remote'}}};
    });
    final repo = PersonnelRepository(client, local: store);
    await repo.synchronize('office');
    expect(await repo.localImportCandidates(), hasLength(1));
    await repo.importLocalRecords('LOCAL-1', 'REMOTE-1');
    expect((await store.list(entityType: 'personnel_outbox')).single.status, LocalSyncStatus.pendingSync);
    repo.dispose();
    final reopened = PersonnelRepository(client, local: store);
    addTearDown(reopened.dispose);
    online = true;
    await reopened.synchronize('office');
    await reopened.importLocalRecords('LOCAL-1', 'REMOTE-1');
    expect(sent, hasLength(1));
    expect(await store.get('local-record-1'), isNotNull);
    await expectLater(reopened.importLocalRecords('LOCAL-1', 'REMOTE-2'), throwsStateError);
  });
  test(
      'authenticated offline edits persist, replay once and deny forbidden cache reads',
      () async {
    final client = _Client();
    final sessions = StreamController<bool>.broadcast(sync: true);
    addTearDown(sessions.close);
    when(() => client.authenticationChanges).thenAnswer((_) => sessions.stream);
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'hr@example.com', fullName: 'HR', roles: ['HR Manager']));
    final store = FakeLocalRecordStore();
    final repo = PersonnelRepository(client, local: store);
    addTearDown(repo.dispose);
    Object? failure;
    int writes = 0;
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      if (failure != null) throw failure;
      final method = invocation.positionalArguments.first as String;
      if (method.endsWith('list_personnel')) {
        return {
          'message': {
            'data': {'rows': [], 'can_edit': true}
          }
        };
      }
      if (method.endsWith('update_personnel')) writes++;
      return {
        'message': {
          'data': {
            'profile': {'id': 'P1', 'display_name': 'قبل'},
            'records': [],
            'revision': '1',
            'can_edit': true
          }
        }
      };
    });
    await repo.list('office');
    await repo.detail('P1');
    failure =
        const ApiException(kind: ApiFailureKind.network, message: 'offline');
    final saved = await repo.update('P1', {'display_name': 'بعد'}, '1');
    expect(saved['pending_sync'], true);
    expect((await repo.detail('P1'))['profile']['display_name'], 'بعد');
    expect((await store.list(entityType: 'personnel_outbox')).single.status,
        LocalSyncStatus.pendingSync);
    await expectLater(
        repo.update('P1', {'display_name': 'سوم'}, '1'), throwsStateError);
    failure =
        const ApiException(kind: ApiFailureKind.forbidden, message: 'denied');
    await expectLater(repo.detail('P1'), throwsA(isA<ApiException>()));
    failure = null;
    await repo.syncPending();
    await repo.syncPending();
    expect(writes, 1);
    expect((await store.list(entityType: 'personnel_outbox')).single.status,
        LocalSyncStatus.synced);
  });

  test('offline cache never crosses authenticated users or logout boundaries',
      () async {
    final client = _Client();
    final sessions = StreamController<bool>.broadcast(sync: true);
    addTearDown(sessions.close);
    when(() => client.authenticationChanges).thenAnswer((_) => sessions.stream);
    when(() => client.isAuthenticated).thenReturn(true);
    var user = 'first';
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        FrappeUserContext(
            userId: user, fullName: user, roles: const ['Employee']));
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'message': {
                'data': {'rows': [], 'can_edit': false}
              }
            });
    final repo = PersonnelRepository(client, local: FakeLocalRecordStore());
    addTearDown(repo.dispose);
    await repo.list('office');
    user = 'second';
    sessions.add(false);
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));
    await expectLater(repo.list('office'), throwsA(isA<ApiException>()));
    sessions.add(false);
    when(() => client.getCurrentUser()).thenThrow(
        const ApiException(kind: ApiFailureKind.network, message: 'offline'));
    await expectLater(repo.list('office'), throwsA(isA<ApiException>()));
  });
  testWidgets('employee detail is read only and excludes financial fields',
      (tester) async {
    final repo = _Repository();
    when(() => repo.detail('self')).thenAnswer((_) async => {
          'profile': {
            'id': 'self',
            'display_name': 'علی',
            'job_title': 'کارشناس',
            'department': 'فروش',
            'bank_name': 'secret-bank',
            'iban': 'secret-iban'
          },
          'records': [],
          'revision': '1',
          'can_edit': false,
        });
    await tester.pumpWidget(
        MaterialApp(home: PersonnelDetailPage(id: 'self', repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اطلاعات فردی'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش'), findsNothing);
    expect(find.text('secret-bank'), findsNothing);
    expect(find.text('secret-iban'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('ویرایش اطلاعات'), findsNothing);
    expect(find.text('نام و نام خانوادگی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('filter combines query department and status', () {
    const state = PersonnelState(rows: [
      {
        'display_name': 'علی',
        'department': 'فروش',
        'job_title': 'کارشناس',
        'disabled': false
      },
      {
        'display_name': 'علی',
        'department': 'مالی',
        'job_title': 'حسابدار',
        'disabled': true
      },
    ], query: 'علی', department: 'فروش', status: 'active');
    expect(state.visible.length, 1);
  });
  test('record validation rejects impossible dates and attendance times', () {
    expect(
        () => validatePersonnelRecord({
              'kind': 'attendance',
              'title': 'کار',
              'date': '2026-09-08',
              'start': '16:00',
              'end': '08:00'
            }),
        throwsFormatException);
    expect(
        () => validatePersonnelRecord(
            {'kind': 'history', 'title': 'کار', 'date': '2026-02-31'}),
        throwsFormatException);
    expect(
        () => validatePersonnelRecord({
              'kind': 'evaluation',
              'title': 'ارزیابی',
              'date': '2026-09-08',
              'score': 80
            }),
        returnsNormally);
  });
  test(
      'local demo uses shared party record but does not expose remote or financial data',
      () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    final store = FakeLocalRecordStore();
    for (final id in ['LOCAL-1', 'REMOTE-1']) {
      await store.save(id: 'party:$id', entityType: 'party_profile', payload: {
        'id': id,
        'company': 'office',
        'roles': ['employee'],
        'display_name': 'علی',
        'bank_name': 'private',
      });
    }
    final repo = PersonnelRepository(client, local: store);
    final list = await repo.list('office');
    expect((list['rows'] as List).length, 1);
    expect((list['rows'] as List).single.containsKey('bank_name'), isFalse);
    final detail = await repo.detail('LOCAL-1');
    await repo.update(
        'LOCAL-1', {'display_name': 'علی جدید'}, '${detail['revision']}');
    expect((await store.get('party:LOCAL-1'))!.payload['display_name'],
        'علی جدید');
    expect((await store.get('party:LOCAL-1'))!.payload['bank_name'], 'private');
    await repo.add(
        'LOCAL-1',
        {
          'kind': 'evaluation',
          'title': 'ارزیابی',
          'date': '2026-09-08',
          'score': 90
        },
        'unique-request');
    await repo.add(
        'LOCAL-1',
        {
          'score': 90,
          'date': '2026-09-08',
          'title': 'ارزیابی',
          'kind': 'evaluation'
        },
        'unique-request');
    await expectLater(
        repo.add(
            'LOCAL-1',
            {
              'score': 80,
              'date': '2026-09-08',
              'title': 'ارزیابی',
              'kind': 'evaluation'
            },
            'unique-request'),
        throwsStateError);
    final reopened = PersonnelRepository(client, local: store);
    await reopened.list('office');
    expect(((await reopened.detail('LOCAL-1'))['records'] as List).length, 2);
    await expectLater(reopened.detail('REMOTE-1'), throwsStateError);
  });
  testWidgets('personnel list search and inactive filter work on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repository();
    when(() => repo.localDemo).thenReturn(false);
    when(() => repo.list('office')).thenAnswer((_) async => {
          'can_edit': true,
          'rows': [
            {
              'id': 'a',
              'display_name': 'علی',
              'job_title': 'کارشناس',
              'department': 'فروش',
              'disabled': false
            },
            {
              'id': 'b',
              'display_name': 'رضا',
              'job_title': 'حسابدار',
              'department': 'مالی',
              'disabled': true
            },
          ]
        });
    await tester.pumpWidget(
        MaterialApp(home: PersonnelPage(company: 'office', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('پرسنل'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, 'غیرفعال (1)'));
    await tester.pumpAndSettle();
    expect(find.text('علی'), findsNothing);
    expect(find.text('رضا'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ناشناخته');
    await tester.pumpAndSettle();
    expect(find.text('پرسنلی با این مشخصات وجود ندارد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
