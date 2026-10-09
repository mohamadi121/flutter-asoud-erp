import 'package:asoud_erp/core/offline/local_database_store.dart';
import 'package:asoud_erp/core/offline/local_record.dart';

class FakeLocalRecordStore implements LocalRecordStore {
  final records = <String, LocalRecord>{};

  @override
  Future<LocalRecord> save({
    String? id,
    required String entityType,
    required Map<String, dynamic> payload,
    LocalSyncStatus status = LocalSyncStatus.localOnly,
    int? attempts,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();
    final recordId = id ?? 'LOCAL-${records.length + 1}';
    final record = LocalRecord(
      id: recordId,
      entityType: entityType,
      payload: payload,
      status: status,
      createdAt: createdAt ?? records[recordId]?.createdAt ?? now,
      updatedAt: now,
      remoteId: records[recordId]?.remoteId,
      attempts: attempts ?? records[recordId]?.attempts ?? 0,
      nextAttemptAt: nextAttemptAt ?? records[recordId]?.nextAttemptAt,
    );
    records[recordId] = record;
    return record;
  }

  @override
  Future<LocalRecord?> get(String id) async => records[id];

  @override
  Future<List<LocalRecord>> list({
    String? entityType,
    Set<LocalSyncStatus>? statuses,
  }) async =>
      // Like the database store: most recently updated first.
      (records.values
          .where(
              (record) => entityType == null || record.entityType == entityType)
          .where(
              (record) => statuses == null || statuses.contains(record.status))
          .toList(growable: false)
          .reversed
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  @override
  Future<void> setStatus(
    String id,
    LocalSyncStatus status, {
    String? remoteId,
    String? error,
    int? attempts,
    DateTime? nextAttemptAt,
  }) async {
    final old = records[id];
    if (old == null) return;
    records[id] = LocalRecord(
      id: old.id,
      entityType: old.entityType,
      payload: old.payload,
      status: status,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      remoteId: remoteId,
      lastError: error,
      attempts: attempts ?? old.attempts,
      nextAttemptAt: nextAttemptAt,
    );
  }

  @override
  Future<void> delete(String id) async => records.remove(id);
}
