import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _server = 'https://erp.example.test';

/// Returns a body made of [chunks] slices of [chunkSize] bytes, all zeros; used
/// to push the response past the client's size cap.
class _OversizedAdapter implements HttpClientAdapter {
  _OversizedAdapter({required this.chunks});

  final int chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody(
        Stream<Uint8List>.fromIterable(
          List<Uint8List>.generate(chunks, (_) => Uint8List(1024 * 1024)),
        ),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Returns a small valid JSON body, to prove the cap does not reject normal
/// responses.
class _SmallAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({'message': 'ok'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

FrappeClient _client(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: _server))..httpClientAdapter = adapter;
  return FrappeClient(baseUrl: _server, dio: dio);
}

void main() {
  test('a response larger than the cap fails with the oversized Persian message',
      () async {
    // 11 MiB of body, above the 10 MiB JSON cap.
    final client = _client(_OversizedAdapter(chunks: 11));
    addTearDown(client.close);

    try {
      await client.callMethod('asoud_erp.api.v1.test.large');
      fail('the call should have failed');
    } on ApiException catch (error) {
      expect(error.kind, ApiFailureKind.responseTooLarge);
      expect(error.message, 'پاسخ سرور بیش از حد بزرگ است.');
      expect(failureMessage(error), 'پاسخ سرور بیش از حد بزرگ است.');
    }
  });

  test('a response below the cap still parses', () async {
    final client = _client(_SmallAdapter());
    addTearDown(client.close);

    final body = await client.callMethod('asoud_erp.api.v1.test.small');

    expect(body, {'message': 'ok'});
  });

  test('the download cap stays above the JSON cap for large downloads', () {
    expect(
      FrappeClient.maxDownloadResponseBytes,
      greaterThan(FrappeClient.maxJsonResponseBytes),
    );
    expect(FrappeClient.maxJsonResponseBytes, 10 * 1024 * 1024);
  });
}
