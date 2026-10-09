import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'message': {
          'ok': true,
          'data': {'schema_version': 2},
          'meta': {'api_version': 'v1'},
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('automatic action options use a direct read-only request', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://erp.example'))
      ..httpClientAdapter = adapter;
    final client = FrappeClient(baseUrl: 'https://erp.example', dio: dio);

    final result = await client.callAsoudMethod(
      'asoud_erp.api.v1.automatic_actions.options',
      data: {'definition': 'WF-1', 'stage': 'ST-1'},
    );

    expect(result, {'schema_version': 2});
    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.single.path,
      '/api/method/asoud_erp.api.v1.automatic_actions.options',
    );
  });
}
