import 'local_database_store.dart';
import 'local_record.dart';

class OfflineMutationStore {
  OfflineMutationStore._();
  static final instance = OfflineMutationStore._();

  Future<String> stage({
    required String operation,
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final record = await LocalDatabaseStore.instance.save(
      entityType: target,
      payload: {'operation': operation, ...payload},
      status: LocalSyncStatus.localOnly,
    );
    return record.id;
  }

  Future<void> markPending(String id) =>
      LocalDatabaseStore.instance.setStatus(id, LocalSyncStatus.pendingSync);

  Future<void> markSynced(String id, {String? remoteId}) =>
      LocalDatabaseStore.instance.setStatus(
        id,
        LocalSyncStatus.synced,
        remoteId: remoteId,
      );

  Future<void> markFailed(String id, Object error) =>
      LocalDatabaseStore.instance.setStatus(
        id,
        LocalSyncStatus.syncFailed,
        error: error.toString(),
      );

  Future<void> remove(String id) => LocalDatabaseStore.instance.delete(id);

  Future<List<Map<String, dynamic>>> pending() async {
    final records = await LocalDatabaseStore.instance.list(statuses: {
      LocalSyncStatus.localOnly,
      LocalSyncStatus.pendingSync,
      LocalSyncStatus.syncFailed,
    });
    return records
        .map((record) => {
              'id': record.id,
              'operation': record.payload['operation'],
              'target': record.entityType,
              'payload': Map<String, dynamic>.from(record.payload)
                ..remove('operation'),
              'created_at': record.createdAt.toIso8601String(),
              'status': record.status.name,
              'last_error': record.lastError,
            })
        .toList(growable: false);
  }
}
