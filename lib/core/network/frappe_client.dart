import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'asoud_api_response.dart';

class FrappeClient {
  FrappeClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.erpNextBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        if (AppConfig.hasApiCredentials)
          'Authorization': 'token ${AppConfig.apiKey}:${AppConfig.apiSecret}',
      },
    );
  }

  final Dio _dio;

  Future<Map<String, dynamic>> getResource(String doctype, String name) async {
    return _request('GET', '/api/resource/$doctype/$name');
  }

  Future<Map<String, dynamic>> createResource(
    String doctype,
    Map<String, dynamic> data,
  ) async {
    return _request('POST', '/api/resource/$doctype', data: data);
  }

  Future<Map<String, dynamic>> updateResource(
    String doctype,
    String name,
    Map<String, dynamic> data,
  ) async {
    return _request('PUT', '/api/resource/$doctype/$name', data: data);
  }

  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    return _request('POST', '/api/method/$method', data: data);
  }

  Future<AsoudApiResponse<T>> callAsoudMethod<T>(
    String method,
    T Function(Object? value) decode, {
    Map<String, dynamic>? data,
  }) async {
    final response = await callMethod(method, data: data);
    final message = response['message'];
    if (message is! Map) {
      throw const ApiException('قالب پاسخ API آسود معتبر نیست.');
    }
    return AsoudApiResponse<T>.parse(
      Map<String, dynamic>.from(message),
      decode,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(method: method),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map<String, dynamic>
          ? _errorMessage(body)
          : 'امکان ارتباط با ERPNext وجود ندارد.';
      final statusCode = error.response?.statusCode;
      final kind = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          ApiFailureKind.timeout,
        DioExceptionType.connectionError => ApiFailureKind.network,
        _ when statusCode == null => ApiFailureKind.network,
        _ when statusCode == 401 => ApiFailureKind.unauthorized,
        _ when statusCode == 403 => ApiFailureKind.forbidden,
        _ when statusCode == 409 => ApiFailureKind.conflict,
        _ when statusCode == 400 || statusCode == 422 =>
          ApiFailureKind.validation,
        _ => ApiFailureKind.server,
      };
      throw ApiException(message, statusCode: statusCode, kind: kind);
    }
  }

  String _errorMessage(Map<String, dynamic> body) {
    final encoded = body['_server_messages'];
    if (encoded is String && encoded.isNotEmpty) {
      try {
        final values = jsonDecode(encoded) as List;
        if (values.isNotEmpty) {
          final decoded = jsonDecode(values.first.toString());
          if (decoded is Map && decoded['message'] != null) {
            return decoded['message'].toString();
          }
        }
      } catch (_) {
        // Fall back to the standard Frappe error fields below.
      }
    }
    return (body['message'] ?? body['exception'] ?? 'خطای ارتباط با سرور')
        .toString();
  }
}
