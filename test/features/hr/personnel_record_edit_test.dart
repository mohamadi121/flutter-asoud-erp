import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  test('offline record edit keeps original ID and replays once after restart', () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.authenticationChanges).thenAnswer((_) => const Stream.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async => const FrappeUserContext(userId: 'hr', fullName: 'HR', roles: ['HR Manager']));
    var online = true;
    var writes = 0;
    var value = <String, dynamic>{'kind': 'evaluation', 'title': 'Review', 'date': '2026-09-12', 'score': 70, '_can_edit': true, '_revision': '1'};
    when(() => client.callMethod(any(), data: any(named: 'data'))).thenAnswer((invocation) async {
      if (!online) throw const ApiException(kind: ApiFailureKind.network, message: 'offline');
      final action = (invocation.positionalArguments.first as String).split('.').last;
      final data = invocation.namedArguments[#data] as Map;
      Map<String, dynamic> result;
      if (action == 'update_record') {
        writes++; value = {...(data['payload'] as Map).cast<String, dynamic>(), '_can_edit': true, '_revision': '2'};
        result = value;
      } else if (action == 'get_record') { result = value; }
      else if (action == 'get_personnel') {
        result = {'profile': {'id': 'person', 'company': 'office'}, 'can_edit': true, 'revision': '1',
          'records': [{'name': 'original', 'kind': value['kind'], 'title': value['title'], 'record_date': value['date']}]};
      } else { result = {'rows': [], 'can_edit': true}; }
      return {'message': {'data': result}};
    });
    final store = FakeLocalRecordStore();
    final repo = PersonnelRepository(client, local: store);
    await repo.list('office');
    await repo.detail('person');
    await repo.record('original');
    online = false;
    await repo.updateRecord('person', 'original', {'kind': 'evaluation', 'title': 'Updated', 'date': '2026-09-12', 'score': 90}, '1', 'request-edit-1');
    final rows = (await repo.detail('person'))['records'] as List;
    expect(rows, hasLength(1)); expect(rows.single['name'], 'original'); expect(rows.single['title'], 'Updated');
    expect((await repo.record('original'))['_can_edit'], false);
    await expectLater(repo.updateRecord('person', 'original', {'kind': 'evaluation', 'title': 'Again', 'date': '2026-09-12', 'score': 90}, '1', 'request-edit-2'), throwsStateError);
    repo.dispose();
    online = true;
    final reopened = PersonnelRepository(client, local: store);
    addTearDown(reopened.dispose);
    await reopened.list('office');
    await reopened.syncPending();
    expect(writes, 1);
    expect((await reopened.record('original'))['_revision'], '2');
    expect((await store.list(entityType: 'personnel_outbox')).single.status, LocalSyncStatus.synced);
  });

  test('local record editing preserves identity, rejects stale edits and protects generated audit', () async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    final store = FakeLocalRecordStore();
    await store.save(id: 'party:LOCAL-1', entityType: 'party_profile', payload: {'id': 'LOCAL-1', 'company': 'office', 'display_name': 'Person', 'roles': ['employee']});
    final repo = PersonnelRepository(client, local: store);
    await repo.list('office');
    await repo.add('LOCAL-1', {'kind': 'history', 'title': 'Original', 'date': '2026-09-12'}, 'request-create');
    const id = 'personnel-demo:request-create';
    final first = await repo.record(id);
    final payload = {'kind': 'history', 'title': 'Updated', 'date': '2026-09-12'};
    await repo.updateRecord('LOCAL-1', id, payload, '${first['_revision']}', 'request-edit');
    await repo.updateRecord('LOCAL-1', id, payload, '${first['_revision']}', 'request-edit');
    expect((await repo.record(id))['title'], 'Updated');
    expect((await repo.detail('LOCAL-1'))['records'], hasLength(2));
    await expectLater(repo.updateRecord('LOCAL-1', id, payload, 'stale', 'request-stale'), throwsStateError);
    final audit = await repo.record('personnel-demo-edit:request-edit');
    expect(audit['_can_edit'], false);
    await expectLater(repo.updateRecord('LOCAL-1', 'personnel-demo-edit:request-edit', payload, '${audit['_revision']}', 'request-audit'), throwsStateError);
  });
}
