enum ApiFailureKind {
  invalidCredentials,
  unauthenticated,
  validation,
  forbidden,
  conflict,
  rateLimited,
  timeout,
  network,
  server,
  protocol,
  cancelled,
  responseTooLarge,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
  });

  const ApiException.protocol()
      : kind = ApiFailureKind.protocol,
        message = 'پاسخ سرور قابل پردازش نیست. لطفاً با پشتیبانی تماس بگیرید.',
        statusCode = null,
        code = null;

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  /// The server's error code (`title` of the first `_server_messages` entry,
  /// e.g. `REQUEST_NOT_EDITABLE`), set only for validation failures (HTTP 417)
  /// whose message was readable.
  final String? code;

  bool get isUnauthorized => kind == ApiFailureKind.unauthenticated;

  @override
  String toString() => 'ApiException($kind, $statusCode)';
}
