import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/offline_sync_service.dart';

/// The number of queued writes still waiting for the server: the same
/// definition as the send-queue screen (`OfflineSyncService.unsent`), so the
/// two never disagree. Local mirror rows (no `operation`) and `synced` rows do
/// not count; owners and servers are not told apart, because the screen lists
/// them all too.
Future<int> countUnsentOfflineRows({LocalRecordStore? store}) async {
  final records = await (store ?? LocalDatabaseStore.instance)
      .list(statuses: unsentQueueStatuses);
  return records.where(isQueuedMutation).length;
}
