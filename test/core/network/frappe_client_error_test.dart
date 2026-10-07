import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/offline_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _server = 'https://erp.example.test';

/// A client whose every call is answered with [status] and [body].
FrappeClient _client(int status, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: _server));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response:
            Response(requestOptions: options, statusCode: status, data: body),
      ),
      true,
    ),
  ));
  return FrappeClient(baseUrl: _server, dio: dio);
}

/// Frappe's `_server_messages`: a JSON string of a list of JSON strings.
String _messages(List<Map<String, Object?>> messages) =>
    jsonEncode([for (final message in messages) jsonEncode(message)]);

Future<ApiException> _failure(FrappeClient client) async {
  try {
    await client.callMethod('asoud_erp.api.v1.workflow_request.update_request',
        data: const {});
  } on ApiException catch (error) {
    return error;
  }
  fail('the call should have failed');
}

void main() {
  test('a 417 exposes the first server message and its code', () async {
    final client = _client(417, {
      'exc_type': 'ValidationError',
      '_server_messages': _messages([
        {
          'message': 'درخواست قابل ویرایش نیست.',
          'title': 'REQUEST_NOT_EDITABLE',
          'indicator': 'red'
        },
        {'message': 'second', 'title': 'OTHER'},
      ]),
    });
    addTearDown(client.close);
    final error = await _failure(client);
    expect(error.statusCode, 417);
    expect(error.kind, ApiFailureKind.validation);
    expect(error.message, 'درخواست قابل ویرایش نیست.');
    expect(error.code, 'REQUEST_NOT_EDITABLE');
    // A business rejection is never retried unchanged.
    expect(isRetryableOfflineFailure(error), isFalse);
  });

  test('markup is stripped and an already decoded list is accepted', () async {
    final client = _client(417, {
      '_server_messages': [
        {
          'message':
              '<div class="ql-editor">مانده <b>کافی</b> نیست&nbsp;.</div>'
        }
      ],
    });
    addTearDown(client.close);
    final error = await _failure(client);
    expect(error.message, 'مانده کافی نیست .');
    expect(error.code, isNull);
  });

  test('an unreadable 417 keeps the generic message', () async {
    for (final body in <Object?>[
      null,
      'Expectation Failed',
      {'_server_messages': 'not json'},
      {'_server_messages': '[]'},
      {'_server_messages': '["{}"]'},
    ]) {
      final client = _client(417, body);
      addTearDown(client.close);
      final error = await _failure(client);
      expect(error.kind, ApiFailureKind.validation, reason: '$body');
      expect(error.message, 'اطلاعات ارسال‌شده معتبر نیست.');
      expect(error.code, isNull);
    }
  });

  test('403 and 5xx never leak server text', () async {
    final body = {
      '_server_messages': _messages([
        {'message': 'secret server detail', 'title': 'SECRET'}
      ]),
      'exception': 'secret server detail',
    };
    for (final (status, kind) in [
      (403, ApiFailureKind.forbidden),
      (500, ApiFailureKind.server),
      (503, ApiFailureKind.server),
      (400, ApiFailureKind.validation),
      (409, ApiFailureKind.conflict),
    ]) {
      final client = _client(status, body);
      addTearDown(client.close);
      final error = await _failure(client);
      expect(error.kind, kind, reason: '$status');
      expect(error.message, isNot(contains('secret')), reason: '$status');
      expect(error.code, isNull, reason: '$status');
    }
  });
}
