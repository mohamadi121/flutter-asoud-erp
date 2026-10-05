import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';

/// Rows that were staged for the server but have not been sent yet:
/// `pendingSync` (waiting/retryable) plus `syncFailed` (needs attention).
/// `localOnly` preview rows and `synced` rows are not unsent server writes.
Future<int> countUnsentOfflineRows({LocalRecordStore? store}) async {
  final records = await (store ?? LocalDatabaseStore.instance).list(
    statuses: const {LocalSyncStatus.pendingSync, LocalSyncStatus.syncFailed},
  );
  return records.length;
}
