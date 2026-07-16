import 'api_exception.dart';

class AsoudApiResponse<T> {
  const AsoudApiResponse({required this.data, required this.apiVersion});

  final T data;
  final String apiVersion;

  static AsoudApiResponse<T> parse<T>(
    Map<String, dynamic> body,
    T Function(Object? value) decode,
  ) {
    if (body['ok'] != true) {
      final error = body['error'];
      final message = error is Map
          ? error['message']?.toString()
          : 'پاسخ نامعتبر از سرور دریافت شد.';
      throw ApiException(message ?? 'خطای نامشخص سرور');
    }

    final meta = body['meta'];
    final version = meta is Map ? meta['api_version']?.toString() : null;
    return AsoudApiResponse<T>(
      data: decode(body['data']),
      apiVersion: version ?? 'v1',
    );
  }
}
