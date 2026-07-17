enum ApiFailureKind {
  invalidCredentials,
  unauthenticated,
  forbidden,
  validation,
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

  final ApiFailureKind kind;
  final String message;
  final int? statusCode;

  bool get isUnauthorized => kind == ApiFailureKind.unauthenticated;

  @override
  String toString() => 'ApiException($kind, $statusCode)';
}
