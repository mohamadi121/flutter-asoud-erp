import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_local_record_store.dart';

class _CatalogClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'Administrator', fullName: 'Administrator', roles: ['Administrator']);

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.role_management.catalog') {
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': {
            'categories': [
              {'code': 'HR', 'title': 'منابع انسانی', 'style': 'hr'},
            ],
            'roles': [
              {
                'code': 'HR_MANAGER',
                'title': '',
                'category': 'HR',
                'parent': '',
                'description': '',
                'enabled': true,
                'profile': 'ASOUD:HR_MANAGER',
                'base_roles': ['HR Manager'],
                'assigned_users': 0,
              },
              {
                'code': 'FIELD_OPS',
                'title': '',
                'category': 'HR',
                'parent': '',
                'description': '',
                'enabled': true,
                'profile': 'ASOUD:FIELD_OPS',
                'base_roles': <String>[],
                'assigned_users': 0,
              },
            ],
            'base_roles': <dynamic>[],
            'templates': <dynamic>[],
            'template_categories': <dynamic>[],
          },
        },
      };
    }
    throw StateError('Unexpected method: $method');
  }
}

void main() {
  test('role codes that are not translated never leak as ALL_CAPS_WITH_UNDERSCORES',
      () {
    expect(persianRoleLabel('HR_MANAGER'), 'مدیر منابع انسانی');
    expect(persianRoleLabel('hr_manager'), 'مدیر منابع انسانی');
    expect(persianRoleLabel('SYSTEM_ADMIN'), 'مدیر سیستم');
    expect(persianRoleLabel('FIN_MGR'), 'مدیر مالی');
    expect(persianRoleLabel('FIELD_OPS'), 'Field Ops');
    expect(persianRoleLabel('نقش سفارشی'), 'نقش سفارشی');
  });

  testWidgets('role tree renders Persian titles instead of raw codes',
      (tester) async {
    final client = _CatalogClient();
    final repository =
        RoleRepository(client, local: FakeLocalRecordStore());
    addTearDown(repository.dispose);

    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RolesPage(repository: repository),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();

    expect(find.text('مدیر منابع انسانی'), findsWidgets);
    expect(find.text('Field Ops'), findsWidgets);
    expect(find.text('HR_MANAGER'), findsNothing);
    expect(find.text('FIELD_OPS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
