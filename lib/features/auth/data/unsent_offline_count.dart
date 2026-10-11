import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/queued_request_adapter.dart';

/// The number of queued writes still waiting for the server: the same
/// definition as the send-queue screen (`OfflineSyncService.unsent`), so the
/// two never disagree. Local mirror rows (no `operation`) and `synced` rows do
/// not count; owners and servers are not told apart, because the screen lists
/// them all too.
Future<int> countUnsentOfflineRows({LocalRecordStore? store}) async {
  final records = await (store ?? LocalDatabaseStore.instance)
      .list(statuses: unsentQueueStatuses);
  // Offline requests (leave, purchase, ...) wait in their own outbox; they count too,
  // otherwise the sign-out warning would not mention a request that is still on the phone.
  // Preview rows (localOnly, no session) are not waiting for any server.
  return records
      .where((r) =>
          isQueuedMutation(r) ||
          (isQueuedRequest(r) && r.status != LocalSyncStatus.localOnly))
      .length;
}
