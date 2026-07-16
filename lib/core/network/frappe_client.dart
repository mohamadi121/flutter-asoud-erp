import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

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
          ? (body['exception'] ?? body['message'] ?? 'خطای ارتباط با سرور').toString()
          : 'امکان ارتباط با ERPNext وجود ندارد.';
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }
}

