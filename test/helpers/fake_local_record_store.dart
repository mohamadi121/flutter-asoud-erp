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
  }) async {
    final now = DateTime.now();
    final recordId = id ?? 'LOCAL-${records.length + 1}';
    final record = LocalRecord(
      id: recordId,
      entityType: entityType,
      payload: payload,
      status: status,
      createdAt: records[recordId]?.createdAt ?? now,
      updatedAt: now,
      remoteId: records[recordId]?.remoteId,
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
      records.values
          .where(
              (record) => entityType == null || record.entityType == entityType)
          .where(
              (record) => statuses == null || statuses.contains(record.status))
          .toList(growable: false);

  @override
  Future<void> setStatus(
    String id,
    LocalSyncStatus status, {
    String? remoteId,
    String? error,
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
    );
  }

  @override
  Future<void> delete(String id) async => records.remove(id);
}
