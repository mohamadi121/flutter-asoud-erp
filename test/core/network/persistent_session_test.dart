import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/session_vault.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vault implements SessionVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String server) async => values[server];
  @override
  Future<void> write(String server, String value) async { values[server] = value; }
  @override
  Future<void> delete(String server) async { values.remove(server); }
}

const server = 'https://erp.example.test';
String _session({DateTime? until, String user = 'hr@example.test'}) => jsonEncode({
  'offline_until': (until ?? DateTime.now().add(const Duration(hours: 1))).toIso8601String(),
  'user': {'user_id': user, 'full_name': 'HR', 'roles': ['HR Manager']},
  'cookie': 'sid=unit-test-session; Path=/; HttpOnly; Secure',
});

Dio _offlineDio({bool unauthorized = false}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    handler.reject(DioException(requestOptions: options,
      type: unauthorized ? DioExceptionType.badResponse : DioExceptionType.connectionError,
      response: unauthorized ? Response(requestOptions: options, statusCode: 401) : null));
  }));
  return dio;
}

void main() {
  test('reopens an unexpired secure session offline without saving a password', () async {
    final vault = _Vault()..values[server] = _session();
    final first = FrappeClient(baseUrl: server, dio: _offlineDio(), sessionVault: vault);
    expect(await first.restoreSession(), true);
    expect((await first.getCurrentUser()).userId, 'hr@example.test');
    await first.close();
    final second = FrappeClient(baseUrl: server, dio: _offlineDio(), sessionVault: vault);
    addTearDown(second.close);
    expect(await second.restoreSession(), true);
    expect((await second.getCurrentUser()).roles, ['HR Manager']);
    expect(vault.values[server], isNot(contains('password')));
  });

  test('expired session and corrupt payload fail closed', () async {
    for (final value in [_session(until: DateTime.now().subtract(const Duration(seconds: 1))), '{bad']) {
      final vault = _Vault()..values[server] = value;
      final client = FrappeClient(baseUrl: server, sessionVault: vault);
      expect(await client.restoreSession(), false);
      expect(client.isAuthenticated, false);
      expect(vault.values, isEmpty);
      await client.close();
    }
  });

  test('logout while offline erases persisted access and never restores it', () async {
    final vault = _Vault()..values[server] = _session();
    final client = FrappeClient(baseUrl: server, dio: _offlineDio(), sessionVault: vault);
    addTearDown(client.close);
    await client.restoreSession();
    await expectLater(client.logout(), throwsA(isA<ApiException>()));
    expect(client.isAuthenticated, false);
    expect(vault.values, isEmpty);
    expect(await client.restoreSession(), false);
  });

  test('server revocation does not fall back to cached identity', () async {
    final vault = _Vault()..values[server] = _session();
    final client = FrappeClient(baseUrl: server, dio: _offlineDio(unauthorized: true), sessionVault: vault);
    addTearDown(client.close);
    await client.restoreSession();
    await expectLater(client.getCurrentUser(), throwsA(isA<ApiException>()));
    expect(client.isAuthenticated, false);
    expect(vault.values, isEmpty);
  });

  test('a different server cannot reuse another server session', () async {
    final vault = _Vault()..values[server] = _session();
    final client = FrappeClient(baseUrl: 'https://other.example.test', sessionVault: vault);
    addTearDown(client.close);
    expect(await client.restoreSession(), false);
    expect(vault.values[server], isNotNull);
  });
}
