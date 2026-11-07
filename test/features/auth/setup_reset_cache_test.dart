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
    final ownPersonnelPending = record('personnel-cache:', ['admin', 'server', 'office'], type: 'personnel_cache', status: LocalSyncStatus.pendingSync);
    final unrelated = [
      record('org-v2:', ['other-server', 'admin', 'office']),
      record('org-v2:', ['server', 'other-admin', 'office']),
      record('org-v2:', ['server', 'admin', 'other-office'], suffix: ':draft'),
      record('role-drafts-v1:', ['server', 'other-admin']),
      record('personnel-cache:', ['other-admin', 'server', 'office'], status: LocalSyncStatus.pendingSync),
      record('unknown:', ['server', 'admin']),
    ];
    final store = _Store([own, ownRoles, ownPersonnel, ownPersonnelPending, ...unrelated]);
    await clearResetCaches(store: store, actor: 'admin', server: 'server', companies: {'office'});
    expect(store.removed, [own.id, ownRoles.id, ownPersonnel.id, ownPersonnelPending.id]);
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
    expect(matches(office(['server', 'admin'], status: LocalSyncStatus.pendingSync)), isTrue);
  });

  test('malformed or ownerless legacy cache is never guessed to belong to this reset', () {
    for (final id in ['org-v2:%broken', 'role-drafts-v1:plain', 'office:legacy']) {
      final row = LocalRecord(id: id, entityType: 'office', payload: const {'company': 'office'},
        status: LocalSyncStatus.synced, createdAt: DateTime(2025), updatedAt: DateTime(2025));
      expect(belongsToReset(row, actor: 'admin', server: 'server', companies: {'office'}), isFalse);
    }
  });

  test('archived organization drafts never block reset as unsent work', () {
    for (final status in LocalSyncStatus.values) {
      final archive = record('org-v2:', ['server', 'admin', 'office'],
          suffix: ':archive:123', type: 'organization_draft_archive', status: status);
      expect(isPendingResetRecord(archive, actor: 'admin', server: 'server'), isFalse);
      expect(belongsToReset(archive, actor: 'admin', server: 'server', companies: {'office'}), isTrue);
      final draft = record('org-v2:', ['server', 'admin', 'office'],
          suffix: ':draft', type: 'organization_draft', status: status);
      expect(isPendingResetRecord(draft, actor: 'admin', server: 'server'),
          status != LocalSyncStatus.synced);
    }
  });

  test('all status and kind combinations for isPendingResetRecord and belongsToReset', () {
    for (final status in LocalSyncStatus.values) {
      final outbox = LocalRecord(
        id: 'outbox-$status',
        entityType: 'personnel_outbox',
        payload: const {'owner': 'admin', 'server': 'server'},
        status: status,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(
        isPendingResetRecord(outbox, actor: 'admin', server: 'server'),
        status != LocalSyncStatus.synced,
      );

      final officeRecord = LocalRecord(
        id: 'office-v2:${Uri.encodeComponent(jsonEncode(['server', 'admin']))}:default',
        entityType: 'office_preference',
        payload: const {'company': 'office'},
        status: status,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(
        isPendingResetRecord(officeRecord, actor: 'admin', server: 'server'),
        status != LocalSyncStatus.synced,
      );
      expect(
        belongsToReset(officeRecord, actor: 'admin', server: 'server', companies: {'office'}),
        isTrue,
      );

      final personnelRecord = LocalRecord(
        id: 'personnel-cache:${Uri.encodeComponent(jsonEncode(['admin', 'server', 'office', 'get_record', {}]))}',
        entityType: 'personnel_cache',
        payload: const {},
        status: status,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(
        belongsToReset(personnelRecord, actor: 'admin', server: 'server', companies: {'office'}),
        isTrue,
      );
    }
  });
}
