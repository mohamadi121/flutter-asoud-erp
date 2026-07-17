import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class FrappeSession {
  const FrappeSession({required this.userId, required this.fullName});

  final String userId;
  final String fullName;
}

abstract interface class FrappeApiClient {
  bool get isAuthenticated;
  Stream<bool> get authenticationChanges;

  Future<FrappeSession> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<List<Map<String, dynamic>>> getResourceList(
    String doctype, {
    Map<String, dynamic>? queryParameters,
  });

  Future<dynamic> callAsoudMethod(
    String method, {
    Map<String, dynamic>? data,
  });

  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  });

  Future<Map<String, dynamic>> createResource(
    String doctype,
    Map<String, dynamic> data,
  );

  Future<Map<String, dynamic>> updateResource(
    String doctype,
    String name,
    Map<String, dynamic> data,
  );
}

class FrappeClient implements FrappeApiClient {
  factory FrappeClient({
    String baseUrl = AppConfig.erpNextBaseUrl,
    String apiKey = AppConfig.erpNextApiKey,
    String apiSecret = AppConfig.erpNextApiSecret,
    Dio? dio,
    CookieJar? cookieJar,
  }) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final client = dio ??
        Dio(
          BaseOptions(
            baseUrl: normalizedBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

    if (client.options.baseUrl.isEmpty) {
      client.options.baseUrl = normalizedBaseUrl;
    }
    client.options.connectTimeout ??= const Duration(seconds: 15);
    client.options.receiveTimeout ??= const Duration(seconds: 20);
    client.options.headers.putIfAbsent('Accept', () => 'application/json');
    client.options.headers
        .putIfAbsent('Content-Type', () => 'application/json');
    if (apiKey.trim().isNotEmpty && apiSecret.trim().isNotEmpty) {
      client.options.headers['Authorization'] =
          'token ${apiKey.trim()}:${apiSecret.trim()}';
    }

    final memoryCookies = cookieJar ?? CookieJar();
    client.interceptors.add(CookieManager(memoryCookies));
    return FrappeClient._(
      client,
      memoryCookies,
      Uri.parse(normalizedBaseUrl),
    );
  }

  FrappeClient._(this._dio, this._cookies, this._baseUri);

  final Dio _dio;
  final CookieJar _cookies;
  final Uri _baseUri;
  final _authenticationController = StreamController<bool>.broadcast();

  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<bool> get authenticationChanges => _authenticationController.stream;

  @override
  Future<FrappeSession> login({
    required String username,
    required String password,
  }) async {
    await _clearSession(notify: false);

    try {
      final loginBody = await _requestJson(
        'POST',
        '/api/method/login',
        data: {'usr': username.trim(), 'pwd': password},
        isLoginRequest: true,
      );
      final fullName = _requiredString(loginBody, 'full_name');

      final userBody = await _requestJson(
        'GET',
        '/api/method/frappe.auth.get_logged_user',
      );
      final userId = _requiredString(userBody, 'message');

      if (!await _hasValidSessionCookie()) {
        throw const ApiException.protocol();
      }

      _setAuthenticated(true);
      return FrappeSession(userId: userId, fullName: fullName);
    } catch (_) {
      await _clearSession(notify: false);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _requestJson('POST', '/api/method/logout');
    } on ApiException catch (error) {
      if (!error.isUnauthorized) rethrow;
    } finally {
      await _clearSession();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getResourceList(
    String doctype, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final body = await _requestJson(
      'GET',
      '/api/resource/${Uri.encodeComponent(doctype)}',
      queryParameters: queryParameters,
    );
    final data = body['data'];
    if (data is! List) throw const ApiException.protocol();

    return data.map((item) {
      if (item is! Map) throw const ApiException.protocol();
      return Map<String, dynamic>.from(item);
    }).toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) =>
      _requestJson('POST', '/api/method/$method', data: data);

  @override
  Future<Map<String, dynamic>> createResource(
    String doctype,
    Map<String, dynamic> data,
  ) =>
      _requestJson(
        'POST',
        '/api/resource/${Uri.encodeComponent(doctype)}',
        data: data,
      );

  @override
  Future<Map<String, dynamic>> updateResource(
    String doctype,
    String name,
    Map<String, dynamic> data,
  ) =>
      _requestJson(
        'PUT',
        '/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(name)}',
        data: data,
      );

  @override
  Future<dynamic> callAsoudMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    final body = await _requestJson(
      'POST',
      '/api/method/$method',
      data: data,
    );
    final message = body['message'];
    if (message is! Map) throw const ApiException.protocol();

    final envelope = Map<String, dynamic>.from(message);
    if (envelope['ok'] != true || !envelope.containsKey('data')) {
      throw const ApiException(
        kind: ApiFailureKind.validation,
        message: 'عملیات در سرور تکمیل نشد. اطلاعات واردشده را بررسی کنید.',
      );
    }

    final meta = envelope['meta'];
    if (meta is! Map || meta['api_version'] != 'v1') {
      throw const ApiException.protocol();
    }
    return envelope['data'];
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    bool isLoginRequest = false,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );
      final body = response.data;
      if (body is! Map) throw const ApiException.protocol();
      return Map<String, dynamic>.from(body);
    } on DioException catch (error) {
      final exception = _safeException(error, isLoginRequest: isLoginRequest);
      if (exception.kind == ApiFailureKind.unauthenticated) {
        await _clearSession();
      }
      throw exception;
    }
  }

  ApiException _safeException(
    DioException error, {
    required bool isLoginRequest,
  }) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return ApiException(
        kind: isLoginRequest
            ? ApiFailureKind.invalidCredentials
            : ApiFailureKind.unauthenticated,
        message: isLoginRequest
            ? 'نام کاربری یا رمز عبور نادرست است.'
            : 'نشست شما منقضی شده است. دوباره وارد شوید.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return ApiException(
        kind: ApiFailureKind.forbidden,
        message: 'اجازه انجام این عملیات را ندارید.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 409) {
      return ApiException(
        kind: ApiFailureKind.conflict,
        message: 'این اطلاعات با داده‌های موجود تداخل دارد.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return ApiException(
        kind: ApiFailureKind.rateLimited,
        message: 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return ApiException(
        kind: ApiFailureKind.validation,
        message: 'اطلاعات ارسال‌شده معتبر نیست.',
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        kind: ApiFailureKind.server,
        message: 'سرور در حال حاضر قادر به پاسخ‌گویی نیست.',
        statusCode: statusCode,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ApiException(
          kind: ApiFailureKind.timeout,
          message: 'زمان اتصال به سرور به پایان رسید.',
        ),
      DioExceptionType.cancel => const ApiException(
          kind: ApiFailureKind.cancelled,
          message: 'درخواست لغو شد.',
        ),
      _ => const ApiException(
          kind: ApiFailureKind.network,
          message: 'ارتباط با سرور برقرار نشد. اتصال شبکه را بررسی کنید.',
        ),
    };
  }

  Future<bool> _hasValidSessionCookie() async {
    final cookies = await _cookies.loadForRequest(_baseUri);
    return cookies.any(
      (cookie) =>
          cookie.name == 'sid' &&
          cookie.value.isNotEmpty &&
          cookie.value.toLowerCase() != 'guest',
    );
  }

  String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! String || value.trim().isEmpty) {
      throw const ApiException.protocol();
    }
    return value.trim();
  }

  void _setAuthenticated(bool value) {
    if (_isAuthenticated == value) return;
    _isAuthenticated = value;
    _authenticationController.add(value);
  }

  Future<void> _clearSession({bool notify = true}) async {
    await _cookies.deleteAll();
    if (notify) _setAuthenticated(false);
    if (!notify) _isAuthenticated = false;
  }

  Future<void> close() async {
    await _cookies.deleteAll();
    await _authenticationController.close();
    _dio.close(force: true);
  }
}
