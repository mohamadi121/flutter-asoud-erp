import '../network/api_exception.dart';

bool isRetryableOfflineFailure(Object error) =>
    error is ApiException &&
    const {
      ApiFailureKind.network,
      ApiFailureKind.timeout,
      ApiFailureKind.server,
    }.contains(error.kind);
