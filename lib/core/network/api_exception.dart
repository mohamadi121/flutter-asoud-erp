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
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const ApiException.protocol()
      : kind = ApiFailureKind.protocol,
        message = 'پاسخ سرور قابل پردازش نیست. لطفاً با پشتیبانی تماس بگیرید.',
        statusCode = null;

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  bool get isUnauthorized => kind == ApiFailureKind.unauthenticated;

  @override
  String toString() => 'ApiException($kind, $statusCode)';
}
