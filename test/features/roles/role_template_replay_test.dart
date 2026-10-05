import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Server-side role catalog that only knows templates applied through it.
class _TemplateServer implements FrappeApiClient {
  final applied = <String>[];
  final failCodes = <String>{};

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'manager',
        fullName: 'Manager',
        roles: ['System Manager'],
      );

  Map<String, dynamic> _catalog() => {
        'categories': [],
        'roles': [
          for (final code in applied)
            {
              'code': code,
              'title': code,
              'category': 'CAT',
              'parent': '',
              'description': '',
              'enabled': true,
              'base_roles': const [],
              'assigned_users': 0,
            },
        ],
        'base_roles': [],
        'templates': [],
        'template_categories': [],
      };

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.apply_templates')) {
      final codes = ((data?['codes'] as List?) ?? const []).cast<String>();
      if (codes.any(failCodes.contains)) {
        throw const ApiException(
          kind: ApiFailureKind.validation,
          message: 'invalid',
        );
      }
      for (final code in codes) {
        if (!applied.contains(code)) applied.add(code);
      }
      return {'applied': codes};
    }
    throw StateError('Unexpected asoud method: $method');
  }

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method.endsWith('.catalog')) {
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': _catalog(),
        },
      };
    }
    throw StateError('Unexpected raw method: $method');
  }

  @override
  Future<FrappeSession> login(
          {required String username, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getResourceList(String doctype,
          {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> createResource(
          String doctype, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> updateResource(
          String doctype, String name, Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<dynamic> replayOfflineMutation(
          {required String mutationId,
          required String operation,
          required String target,
          required Map<String, dynamic> data}) =>
      throw UnimplementedError();
}

String _draftKey() =>
    'role-drafts-v1:${Uri.encodeComponent(jsonEncode(['test', 'manager']))}';

void main() {
  test('staged apply_templates stays pending until every code is applied',
      () async {
    final store = FakeLocalRecordStore();
    final client = _TemplateServer()..failCodes.add('B');
    await store.save(
      id: _draftKey(),
      entityType: 'role_drafts',
      payload: {
        'catalog': {
          'categories': [],
          'roles': [],
          'base_roles': [],
          'templates': [],
          'template_categories': [],
        },
        'drafts': [
          {
            'kind': 'template',
            'code': 'A',
            'values': {'code': 'A'},
          },
          {
            'kind': 'template',
            'code': 'B',
            'values': {'code': 'B'},
          },
        ],
      },
    );
    await store.save(
      id: 'staged-apply',
      entityType: 'asoud_erp.api.v1.role_management.apply_templates',
      payload: const {
        'codes': ['A', 'B'],
        'operation': 'asoud_method',
        '_asoud_owner': 'manager',
        '_asoud_server': 'test',
      },
      status: LocalSyncStatus.pendingSync,
    );

    final repository = RoleRepository(client, local: store);
    addTearDown(repository.dispose);

    // A applies, B is rejected: the staged row must NOT be marked synced or
    // B would lose its automatic replay.
    await expectLater(
      repository.synchronize(),
      throwsA(isA<ApiException>()),
    );
    expect(client.applied, ['A']);
    expect(repository.pendingCount, 1);
    expect(
      (await store.get('staged-apply'))!.status,
      LocalSyncStatus.pendingSync,
    );

    // Once B applies too, the staged row is fully replayed.
    client.failCodes.clear();
    await repository.synchronize();
    expect(client.applied, ['A', 'B']);
    expect(repository.pendingCount, 0);
    expect(
      (await store.get('staged-apply'))!.status,
      LocalSyncStatus.synced,
    );
  });
}
