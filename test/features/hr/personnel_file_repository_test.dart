import 'dart:async';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeClient {}

void main() {
  const prefix = 'asoud_erp.api.v1.personnel_file.';
  const offline =
      ApiException(kind: ApiFailureKind.network, message: 'offline');
  late _Client client;
  late FakeLocalRecordStore store;
  late PersonnelFileRepository repo;
  late String user;
  late String server;
  late Object? failure;
  late StreamController<bool> sessions;
  late Future<dynamic> Function(String, Map<String, dynamic>) respond;

  setUp(() {
    client = _Client();
    store = FakeLocalRecordStore();
    user = 'employee-a';
    server = 'https://office.example';
    failure = null;
    sessions = StreamController<bool>.broadcast(sync: true);
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenAnswer((_) => server);
    when(() => client.authenticationChanges).thenAnswer((_) => sessions.stream);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        FrappeUserContext(
            userId: user, fullName: user, roles: const ['Employee']));
    respond = (method, data) async {
      if (failure != null) throw failure!;
      switch (method) {
        case '${prefix}get_personnel_file':
          return {'profile_id': data['name'], 'revision': 'r1'};
        case '${prefix}get_my_personnel_file':
          return {'profile_id': 'MY-FILE'};
        case '${prefix}get_my_home':
          return {'name': 'امیر موفق'};
        case '${prefix}list_announcements':
          return [
            {'name': 'NOTE-1', 'title': 'جلسه'}
          ];
        case '${prefix}get_contract_file':
          return {'filename': 'contract.pdf', 'content_base64': 'YWJj'};
        case '${prefix}save_contract':
          return [
            {'name': 'CONTRACT-1', 'is_signed': data['is_signed']}
          ];
        default:
          return null;
      }
    };
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) => respond(call.positionalArguments.single as String,
            Map<String, dynamic>.from(call.namedArguments[#data] as Map)));
    repo = PersonnelFileRepository(client, store: store);
  });

  tearDown(() async {
    await sessions.close();
  });

  test('reads use exact methods, arguments and typed results', () async {
    expect((await repo.file('PARTY-0042')).profileId, 'PARTY-0042');
    expect((await repo.myFile()).profileId, 'MY-FILE');
    expect((await repo.myHome()).firstName, 'امیر');
    expect((await repo.announcements()).single.name, 'NOTE-1');
    verify(() => client.callAsoudMethod('${prefix}get_personnel_file',
        data: {'name': 'PARTY-0042'})).called(1);
    for (final method in [
      'get_my_personnel_file',
      'get_my_home',
      'list_announcements'
    ]) {
      verify(() => client.callAsoudMethod('$prefix$method', data: {}))
          .called(1);
    }
    final records = await store.list(entityType: 'personnel_file_cache');
    expect(records, hasLength(4));
    expect(records.map((row) => row.payload['value']),
        contains(equals({'profile_id': 'PARTY-0042', 'revision': 'r1'})));
  });

  test('all four reads use their own cached raw values offline', () async {
    await repo.file('PARTY-0042');
    await repo.myFile();
    await repo.myHome();
    await repo.announcements();
    failure = offline;
    expect((await repo.file('PARTY-0042')).revision, 'r1');
    expect((await repo.myFile()).profileId, 'MY-FILE');
    expect((await repo.myHome()).name, 'امیر موفق');
    expect((await repo.announcements()).single.title, 'جلسه');
    await expectLater(repo.file('OTHER'), throwsA(same(offline)));
    failure = TimeoutException('timed out');
    expect((await repo.file('PARTY-0042')).profileId, 'PARTY-0042');
  });

  test('permission and validation errors rethrow even with a cache', () async {
    await repo.file('PARTY-0042');
    for (final kind in [
      ApiFailureKind.forbidden,
      ApiFailureKind.validation,
      ApiFailureKind.unauthenticated
    ]) {
      failure = ApiException(kind: kind, message: 'denied');
      await expectLater(repo.file('PARTY-0042'), throwsA(same(failure)));
    }
  });

  test('cache is isolated by user and server, including a new repository',
      () async {
    await repo.file('PARTY-0042');
    failure = offline;
    user = 'employee-b';
    await expectLater(repo.file('PARTY-0042'), throwsA(same(offline)));
    user = 'employee-a';
    server = 'https://other.example';
    await expectLater(repo.file('PARTY-0042'), throwsA(same(offline)));
    server = 'https://office.example';
    final restarted = PersonnelFileRepository(client, store: store);
    expect((await restarted.file('PARTY-0042')).profileId, 'PARTY-0042');
  });

  test('a session change during an offline read cannot expose cached data',
      () async {
    await repo.file('PARTY-0042');
    final pending = Completer<dynamic>();
    final started = Completer<void>();
    respond = (_, __) {
      started.complete();
      return pending.future;
    };
    final read = repo.file('PARTY-0042');
    final expectation = expectLater(
        read, throwsA(anyOf(isA<ApiException>(), isA<StateError>())));
    await started.future;
    user = 'employee-b';
    sessions.add(false);
    sessions.add(true);
    pending.completeError(offline);
    await expectation;
  });

  test('contract file is downloaded without caching or offline fallback',
      () async {
    final result = await repo.contractFile('CONTRACT-1');
    expect(result, (filename: 'contract.pdf', contentBase64: 'YWJj'));
    verify(() => client.callAsoudMethod('${prefix}get_contract_file',
        data: {'contract': 'CONTRACT-1'})).called(1);
    expect(store.records, isEmpty);
    failure = offline;
    await expectLater(repo.contractFile('CONTRACT-1'), throwsA(same(offline)));
  });

  test('save contract sends optional fields and integer booleans', () async {
    final result = await repo.saveContract(
        profileId: 'PARTY-0042',
        startDate: '2026-01-01',
        terms: 'شرایط',
        endDate: '2026-12-31',
        contract: 'CONTRACT-1',
        isSigned: true,
        fileBase64: 'YWJj',
        filename: 'contract.pdf',
        submit: true);
    expect(result.single.name, 'CONTRACT-1');
    expect(result.single.isSigned, isTrue);
    verify(() => client.callAsoudMethod('${prefix}save_contract', data: {
          'name': 'PARTY-0042',
          'start_date': '2026-01-01',
          'terms': 'شرایط',
          'end_date': '2026-12-31',
          'contract': 'CONTRACT-1',
          'is_signed': 1,
          'file': 'YWJj',
          'filename': 'contract.pdf',
          'submit': 1,
        })).called(1);
    await repo.saveContract(
        profileId: 'PARTY-0042', startDate: '2026-01-01', terms: 'شرایط');
    verify(() => client.callAsoudMethod('${prefix}save_contract', data: {
          'name': 'PARTY-0042',
          'start_date': '2026-01-01',
          'terms': 'شرایط',
          'is_signed': 0,
          'submit': 0,
        })).called(1);
    expect(store.records, isEmpty);
  });

  test('promotion and announcement writes omit null optional arguments',
      () async {
    await repo.addPromotion(
        profileId: 'PARTY-0042', promotionDate: '2026-09-25');
    verify(() => client.callAsoudMethod('${prefix}add_promotion', data: {
          'name': 'PARTY-0042',
          'promotion_date': '2026-09-25',
        })).called(1);
    await repo.addPromotion(
        profileId: 'PARTY-0042',
        promotionDate: '2026-09-25',
        designation: 'سرپرست',
        department: 'Sales - T',
        branch: 'تهران',
        remarks: 'ارتقا');
    verify(() => client.callAsoudMethod('${prefix}add_promotion', data: {
          'name': 'PARTY-0042',
          'promotion_date': '2026-09-25',
          'designation': 'سرپرست',
          'department': 'Sales - T',
          'branch': 'تهران',
          'remarks': 'ارتقا',
        })).called(1);
    await repo.createAnnouncement(title: 'جلسه', content: 'فردا');
    verify(() => client.callAsoudMethod('${prefix}create_announcement',
        data: {'title': 'جلسه', 'content': 'فردا'})).called(1);
    await repo.createAnnouncement(
        title: 'جلسه', content: 'فردا', expireOn: '2026-09-26');
    verify(() => client.callAsoudMethod('${prefix}create_announcement', data: {
          'title': 'جلسه',
          'content': 'فردا',
          'expire_on': '2026-09-26',
        })).called(1);
    expect(store.records, isEmpty);
    failure = offline;
    await expectLater(
        repo.saveContract(
            profileId: 'PARTY-0042', startDate: '2026-01-01', terms: ''),
        throwsA(same(offline)));
    await expectLater(
        repo.addPromotion(profileId: 'PARTY-0042', promotionDate: '2026-09-25'),
        throwsA(same(offline)));
    await expectLater(repo.createAnnouncement(title: 'جلسه', content: 'فردا'),
        throwsA(same(offline)));
    expect(store.records, isEmpty);
  });
}
