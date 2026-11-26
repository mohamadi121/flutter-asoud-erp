import 'local_database_store.dart';
import 'local_record.dart';

/// Scratch records are never shared with a signed-in account's device data.
final class SessionRecordStore implements LocalRecordStore {
  final _rows = <String, LocalRecord>{};
  int _nextId = 0;

  void clear() => _rows.clear();

  @override
  Future<LocalRecord> save({
    String? id, required String entityType, required Map<String, dynamic> payload,
    LocalSyncStatus status = LocalSyncStatus.localOnly,
    int? attempts, DateTime? nextAttemptAt,
  }) async {
    final key = id ?? 'LOCAL-SESSION-${_nextId++}';
    final old = _rows[key];
    final now = DateTime.now();
    final record = LocalRecord(id: key, entityType: entityType, payload: payload,
      status: status, createdAt: old?.createdAt ?? now, updatedAt: now,
      attempts: attempts ?? old?.attempts ?? 0, nextAttemptAt: nextAttemptAt);
    return _rows[key] = LocalRecord.fromRow(record.toRow());
  }

  @override
  Future<LocalRecord?> get(String id) async => _rows[id];

  @override
  Future<List<LocalRecord>> list({String? entityType, Set<LocalSyncStatus>? statuses}) async =>
      _rows.values.where((r) => (entityType == null || r.entityType == entityType)
          && (statuses == null || statuses.contains(r.status))).toList();

  @override
  Future<void> setStatus(String id, LocalSyncStatus status, {
    String? remoteId, String? error, int? attempts, DateTime? nextAttemptAt,
  }) async {
    final old = _rows[id];
    if (old == null) return;
    _rows[id] = LocalRecord(id: id, entityType: old.entityType, payload: old.payload,
      status: status, createdAt: old.createdAt, updatedAt: DateTime.now(),
      remoteId: remoteId ?? old.remoteId, lastError: error,
      attempts: attempts ?? old.attempts, nextAttemptAt: nextAttemptAt);
  }

  @override
  Future<void> delete(String id) async => _rows.remove(id);
}
