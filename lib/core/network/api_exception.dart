enum ApiFailureKind {
  validation,
  unauthorized,
  forbidden,
  conflict,
  timeout,
  network,
  server,
  protocol
}

class ApiException implements Exception {
  const ApiException(this.message,
      {this.statusCode, this.kind = ApiFailureKind.server});

  final String message;
  final int? statusCode;
  final ApiFailureKind kind;

  @override
  String toString() => message;
}
