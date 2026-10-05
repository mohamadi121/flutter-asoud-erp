import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _server = 'https://erp.example.test';
const _mutationPath = '/api/method/asoud_erp.api.v1.sync.execute_mutation';

Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
      'message': {
        'ok': true,
        'data': data,
        'meta': {'api_version': 'v1'},
      },
    };

class _Sent {
  _Sent(this.path, this.body, this.headers);
  final String path;
  final Map<String, dynamic> body;
  final Map<String, dynamic> headers;
}

Dio _fakeDio(
  List<_Sent> sent, {
  required Future<void> Function(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) onMutation,
}) {
  final dio = Dio(BaseOptions(baseUrl: _server));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (options.path == _mutationPath) {
        await onMutation(options, handler);
        return;
      }
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ));
    },
  ));
  return dio;
}

void main() {
  test('replay sends a stable request key with the exact payload', () async {
    final sent = <_Sent>[];
    final client = FrappeClient(
      baseUrl: _server,
      dio: _fakeDio(sent, onMutation: (options, handler) async {
        sent.add(_Sent(
          options.path,
          Map<String, dynamic>.from(options.data as Map),
          Map<String, dynamic>.from(options.headers),
        ));
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: _envelope(const {'name': 'REMOTE-1'}),
        ));
      }),
    );
    addTearDown(client.close);

    final result = await client.replayOfflineMutation(
      mutationId: 'mutation-1',
      operation: 'asoud_method',
      target: 'asoud_erp.api.v1.setup.save_office',
      data: const {'company_name': 'دفتر نمونه'},
    );

    expect(result, {'name': 'REMOTE-1'});
    expect(sent, hasLength(1));
    expect(sent.single.path, _mutationPath);
    expect(sent.single.body['request_key'], 'mutation-1');
    expect(sent.single.body['target_method'],
        'asoud_erp.api.v1.setup.save_office');
    expect(jsonDecode(sent.single.body['payload'] as String),
        {'company_name': 'دفتر نمونه'});
    expect(sent.single.headers['X-ASOUD-Idempotency-Key'], 'mutation-1');
  });

  test('retry after a timeout resends the same key and payload', () async {
    final sent = <_Sent>[];
    final writes = <String, int>{};
    var failFirstWithTimeout = true;
    final client = FrappeClient(
      baseUrl: _server,
      dio: _fakeDio(sent, onMutation: (options, handler) async {
        final body = Map<String, dynamic>.from(options.data as Map);
        sent.add(_Sent(
          options.path,
          body,
          Map<String, dynamic>.from(options.headers),
        ));
        final key = body['request_key'] as String;
        if (failFirstWithTimeout) {
          // The server committed before the client observed the timeout.
          writes[key] = (writes[key] ?? 0) + 1;
          failFirstWithTimeout = false;
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ));
          return;
        }
        if (writes.containsKey(key)) {
          // Idempotent replay of an already committed key writes nothing new.
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _envelope(const {'name': 'REMOTE-1'}),
          ));
          return;
        }
        writes[key] = (writes[key] ?? 0) + 1;
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: _envelope(const {'name': 'REMOTE-1'}),
        ));
      }),
    );
    addTearDown(client.close);

    const data = {'company_name': 'دفتر نمونه'};
    await expectLater(
      client.replayOfflineMutation(
        mutationId: 'mutation-1',
        operation: 'asoud_method',
        target: 'asoud_erp.api.v1.setup.save_office',
        data: data,
      ),
      throwsA(isA<ApiException>()
          .having((error) => error.kind, 'kind', ApiFailureKind.timeout)),
    );
    final result = await client.replayOfflineMutation(
      mutationId: 'mutation-1',
      operation: 'asoud_method',
      target: 'asoud_erp.api.v1.setup.save_office',
      data: data,
    );

    expect(result, {'name': 'REMOTE-1'});
    expect(sent, hasLength(2));
    expect(sent[1].body['request_key'], sent[0].body['request_key']);
    expect(sent[1].body['request_key'], 'mutation-1');
    expect(sent[1].body['payload'], sent[0].body['payload']);
    expect(jsonDecode(sent[1].body['payload'] as String),
        {'company_name': 'دفتر نمونه'});
    expect(writes['mutation-1'], 1);
  });
}
