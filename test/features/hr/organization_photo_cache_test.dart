import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// Serves the employee photo endpoint and counts every request that reaches
/// the transport, so tests can tell cache hits from network calls.
class PhotoClient implements FrappeApiClient {
  PhotoClient({this.employees = const {}});

  /// Employee id to base64 content; a missing id answers with no photo.
  final Map<String, String> employees;
  final Set<String> failing = {};
  final List<String> photoRequests = [];
  final StreamController<bool> sessionChanges =
      StreamController<bool>.broadcast();
  Completer<void>? gate;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => sessionChanges.stream;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'hr-user',
        fullName: 'HR',
        roles: ['HR User'],
      );

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    final endpoint = method.split('.').last;
    final body = switch (endpoint) {
      'employee_photo' => await _photo('${data?['employee']}'),
      'get_chart' => {'revision': 1, 'rows': positions, 'warnings': []},
      'list_units' => {'units': [], 'can_manage': false},
      'list_employees' => {'employees': people},
      _ => throw StateError('Unexpected method: $method'),
    };
    return {
      'message': {
        'ok': true,
        'data': body,
        'meta': {'api_version': 'v1'},
      },
    };
  }

  Future<Map<String, dynamic>> _photo(String employee) async {
    photoRequests.add(employee);
    await gate?.future;
    if (failing.contains(employee)) {
      throw const ApiException(
          kind: ApiFailureKind.network, message: 'offline');
    }
    return {'content': employees[employee]};
  }

  /// Root positions, each occupied by one employee. Rows and people are
  /// shaped like the backend's `get_chart` and `list_employees` answers.
  List<Map<String, dynamic>> positions = const [];
  List<Map<String, dynamic>> people = const [];

  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) =>
      throw UnimplementedError();

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

final _pngBytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
final _pngBase64 = base64Encode(_pngBytes);

void main() {
  late PhotoClient client;
  late OrganizationRepository repository;

  setUp(() {
    client = PhotoClient(employees: {'employee:EMP-1': _pngBase64});
    repository = OrganizationRepository(client, local: FakeLocalRecordStore());
  });

  tearDown(() async {
    await repository.dispose();
    await client.sessionChanges.close();
  });

  test('at most four photo requests are in flight at once', () async {
    client.gate = Completer<void>();
    final reads = [
      for (var i = 0; i < 10; i++)
        repository.employeePhoto('شرکت', 'employee:E$i'),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(client.photoRequests, hasLength(OrganizationRepository.maxPhotoRequests));
    client.gate!.complete();
    await Future.wait(reads);
    expect(client.photoRequests, hasLength(10));
  });

  test('a photo is fetched once and later reads come from the cache', () async {
    final first = await repository.employeePhoto('شرکت', 'employee:EMP-1');
    final second = await repository.employeePhoto('شرکت', 'employee:EMP-1');

    expect(first, _pngBytes);
    expect(second, _pngBytes);
    expect(client.photoRequests, ['employee:EMP-1']);
  });

  test('assignment or profile refresh invalidates the existing photo cache', () async {
    await repository.employeePhoto('شرکت', 'employee:EMP-1');
    repository.invalidateEmployeePhotos();
    await repository.employeePhoto('شرکت', 'employee:EMP-1');
    expect(client.photoRequests, ['employee:EMP-1', 'employee:EMP-1']);
  });

  test('concurrent reads for one employee share a single request', () async {
    final results = await Future.wait([
      repository.employeePhoto('شرکت', 'employee:EMP-1'),
      repository.employeePhoto('شرکت', 'employee:EMP-1'),
    ]);

    expect(results, [_pngBytes, _pngBytes]);
    expect(client.photoRequests, hasLength(1));
  });

  test('an employee without a photo is cached as null', () async {
    final first = await repository.employeePhoto('شرکت', 'employee:EMP-2');
    final second = await repository.employeePhoto('شرکت', 'employee:EMP-2');

    expect(first, isNull);
    expect(second, isNull);
    expect(client.photoRequests, ['employee:EMP-2']);
  });

  test('a failed request is cached for the rest of the session', () async {
    client.failing.add('employee:EMP-1');
    await expectLater(
        repository.employeePhoto('شرکت', 'employee:EMP-1'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.network)));
    client.failing.clear();

    await expectLater(
        repository.employeePhoto('شرکت', 'employee:EMP-1'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.network)));

    expect(client.photoRequests, ['employee:EMP-1']);
  });

  test('the cache keeps every employee photo for the current session',
      () async {
    for (var i = 0; i < 200; i++) {
      await repository.employeePhoto('شرکت', 'employee:P-$i');
    }
    await repository.employeePhoto('شرکت', 'employee:P-200');
    client.photoRequests.clear();

    await repository.employeePhoto('شرکت', 'employee:P-0');
    await repository.employeePhoto('شرکت', 'employee:P-1');

    expect(client.photoRequests, isEmpty);
  });

  test('sign-out clears the cache so the next read asks the server again',
      () async {
    await repository.employeePhoto('شرکت', 'employee:EMP-1');
    client.sessionChanges.add(false);
    await Future<void>.delayed(Duration.zero);

    await repository.employeePhoto('شرکت', 'employee:EMP-1');

    expect(client.photoRequests, ['employee:EMP-1', 'employee:EMP-1']);
  });

  test('switching company clears the cache for the previous company', () async {
    await repository.employeePhoto('شرکت الف', 'employee:EMP-1');
    await repository.employeePhoto('شرکت ب', 'employee:EMP-1');
    await repository.employeePhoto('شرکت الف', 'employee:EMP-1');

    expect(client.photoRequests, hasLength(3));
  });
}
