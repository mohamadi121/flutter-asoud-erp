import '../network/api_exception.dart';

bool isRetryableOfflineFailure(Object error) =>
    error is ApiException &&
    const {
      ApiFailureKind.network,
      ApiFailureKind.timeout,
      ApiFailureKind.server,
    }.contains(error.kind);

/// Whether the error means "safely queued, will replay automatically". The
/// core queue does not expose its QueuedOfflineException type here yet, so
/// this matches by name; replace with `error is QueuedOfflineException` once
/// the type lands.
bool isQueuedOffline(Object error) =>
    error.runtimeType.toString() == 'QueuedOfflineException';
