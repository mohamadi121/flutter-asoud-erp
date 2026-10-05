import '../network/api_exception.dart';
import 'queued_offline_exception.dart';

/// Status codes the server rejects on its own terms. Replaying such a write
/// unchanged only wastes the queue, so it waits for the user instead.
const terminalOfflineStatusCodes = <int>{400, 403, 409, 417};

/// Whether the write can still succeed later without any change from the user.
/// A [QueuedOfflineException] qualifies: the write is on the device already.
bool isRetryableOfflineFailure(Object error) {
  if (error is QueuedOfflineException) return true;
  if (error is! ApiException) return false;
  if (terminalOfflineStatusCodes.contains(error.statusCode)) return false;
  return const {
    ApiFailureKind.network,
    ApiFailureKind.timeout,
    ApiFailureKind.server,
  }.contains(error.kind);
}

/// The Persian text a user should read for a write that failed.
String offlineFailureMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is QueuedOfflineException) return error.message;
  return error.toString();
}
