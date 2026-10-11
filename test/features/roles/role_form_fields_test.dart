import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// An authenticated client whose catalog has one category so the «ایجاد نقش
/// دستی» card of the setup view is enabled.
class _CategoryClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: const ['Administrator'],
      );

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method != 'asoud_erp.api.v1.role_management.catalog') {
      throw StateError('Unexpected role API method: $method');
    }
    return {
      'message': {
        'ok': true,
        'meta': {'api_version': 'v1'},
        'data': {
          'categories': [
            {'code': 'MANAGERS', 'title': 'مدیران', 'style': 'managers'},
          ],
          'roles': <dynamic>[],
          'base_roles': <dynamic>[],
          'templates': <dynamic>[],
          'template_categories': [
            {'code': 'MANAGERS', 'title': 'مدیران', 'style': 'managers'},
          ],
        },
      },
    };
  }
}

Future<void> _openCreateForm(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final client = _CategoryClient();
  final repository = RoleRepository(client, local: FakeLocalRecordStore());
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

  await tester.tap(find.text('ایجاد نقش دستی'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'role create form renders the shared AppTextField, AppSelectField and '
        'AppSwitchTile at ${width.toInt()} px RTL', (tester) async {
      await _openCreateForm(tester, width);

      expect(find.text('نام نقش *'), findsOneWidget);
      expect(find.byType(AppTextField), findsNWidgets(3));
      expect(find.byType(AppSelectField), findsNWidgets(2));
      expect(find.byType(AppSwitchTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}