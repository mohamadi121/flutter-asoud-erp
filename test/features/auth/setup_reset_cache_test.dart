import 'dart:convert';

import 'package:asoud_erp/core/offline/local_database_store.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/auth/data/setup_reset_cache.dart';
import 'package:flutter_test/flutter_test.dart';

LocalRecord record(String prefix, List<dynamic> scope, {String suffix = '', String type = 'organization_chart',
    LocalSyncStatus status = LocalSyncStatus.synced}) => LocalRecord(
  id: '$prefix${Uri.encodeComponent(jsonEncode(scope))}$suffix', entityType: type,
  payload: const {}, status: status, createdAt: DateTime(2025), updatedAt: DateTime(2025));

class _Store extends Fake implements LocalRecordStore {
  _Store(this.records);
  final List<LocalRecord> records;
  final removed = <String>[];
  @override
  Future<List<LocalRecord>> list({String? entityType, Set<LocalSyncStatus>? statuses}) async => records;
  @override
  Future<void> delete(String id) async => removed.add(id);
}

void main() {
  test('pending personnel outbox blocks reset only for its owner and server', () {
    final row = LocalRecord(id: 'outbox-id', entityType: 'personnel_outbox',
      payload: const {'owner': 'admin', 'server': 'server', 'company': 'office'},
      status: LocalSyncStatus.pendingSync, createdAt: DateTime(2025), updatedAt: DateTime(2025));
    expect(isPendingResetRecord(row, actor: 'admin', server: 'server'), isTrue);
    expect(isPendingResetRecord(row, actor: 'other-admin', server: 'server'), isFalse);
    expect(isPendingResetRecord(row, actor: 'admin', server: 'other-server'), isFalse);
    expect(belongsToReset(row, actor: 'admin', server: 'server', companies: {'office'}), isFalse);
  });
  test('only confirmed own-site own-office caches and role drafts are removed', () async {
    final own = record('org-v2:', ['server', 'admin', 'office'], suffix: ':draft',
        type: 'organization_draft', status: LocalSyncStatus.localOnly);
    final ownRoles = record('role-drafts-v1:', ['server', 'admin'], type: 'role_drafts');
    final ownPersonnel = record('personnel-cache:', ['admin', 'server', 'office', 'get_record', {}], type: 'personnel_cache');
    final unrelated = [
      record('org-v2:', ['other-server', 'admin', 'office']),
      record('org-v2:', ['server', 'other-admin', 'office']),
      record('org-v2:', ['server', 'admin', 'other-office'], suffix: ':draft'),
      record('role-drafts-v1:', ['server', 'other-admin']),
      record('personnel-cache:', ['admin', 'server', 'office'], status: LocalSyncStatus.pendingSync),
      record('unknown:', ['server', 'admin']),
    ];
    final store = _Store([own, ownRoles, ownPersonnel, ...unrelated]);
    await clearResetCaches(store: store, actor: 'admin', server: 'server', companies: {'office'});
    expect(store.removed, [own.id, ownRoles.id, ownPersonnel.id]);
    expect(store.removed.any((id) => unrelated.any((row) => row.id == id)), isFalse);
  });

  test('no office scope never clears another office chart', () {
    final chart = record('org-v2:', ['server', 'admin', 'office']);
    expect(belongsToReset(chart, actor: 'admin', server: 'server', companies: {}), isFalse);
  });

  test('office and default caches require exact actor, server and confirmed office', () {
    LocalRecord office(List<String> identity, {LocalSyncStatus status = LocalSyncStatus.synced}) => LocalRecord(
      id: 'office-v2:${Uri.encodeComponent(jsonEncode(identity))}:default', entityType: 'office_preference',
      payload: const {'company': 'office'}, status: status, createdAt: DateTime(2025), updatedAt: DateTime(2025));
    bool matches(LocalRecord row) => belongsToReset(row, actor: 'admin', server: 'server', companies: {'office'});
    expect(matches(office(['server', 'admin'])), isTrue);
    expect(matches(office(['other-server', 'admin'])), isFalse);
    expect(matches(office(['server', 'other-admin'])), isFalse);
    expect(matches(office(['server', 'admin'], status: LocalSyncStatus.pendingSync)), isFalse);
  });

  test('malformed or ownerless legacy cache is never guessed to belong to this reset', () {
    for (final id in ['org-v2:%broken', 'role-drafts-v1:plain', 'office:legacy']) {
      final row = LocalRecord(id: id, entityType: 'office', payload: const {'company': 'office'},
        status: LocalSyncStatus.synced, createdAt: DateTime(2025), updatedAt: DateTime(2025));
      expect(belongsToReset(row, actor: 'admin', server: 'server', companies: {'office'}), isFalse);
    }
  });
}
