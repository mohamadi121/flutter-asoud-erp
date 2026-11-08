import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

/// A 60-character Persian title used to prove the sheet does not overflow at
/// 320 and 390 px.
const _longTitle =
    'مدیر مالی و حسابداری و امور اداری و پشتیبانی فنی و پشتیبانیه';

/// An authenticated client that serves one role and records the exact
/// `save_role` payload it receives, so a category-only edit can be asserted to
/// keep the role's base roles unchanged.
class _RoleClient extends Fake implements FrappeApiClient {
  _RoleClient(this.catalog);
  final RoleCatalog catalog;
  final savedPayloads = <Map<String, dynamic>>[];

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
        'data': _encode(catalog),
      },
    };
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method != 'asoud_erp.api.v1.role_management.save_role') {
      throw StateError('Unexpected asoud method: $method');
    }
    final payload = Map<String, dynamic>.from((data?['payload'] ?? {}) as Map);
    savedPayloads.add(payload);
    return {
      ...payload,
      'enabled': payload['enabled'] == 1,
      'assigned_users': payload['assigned_users'] ?? 0,
    };
  }

  Map<String, dynamic> _encode(RoleCatalog catalog) => {
        'categories': catalog.categories
            .map((e) => {'code': e.code, 'title': e.title, 'style': e.style})
            .toList(),
        'roles': catalog.roles
            .map((e) => {
                  ...e.toJson(),
                  'enabled': e.enabled,
                  'assigned_users': e.assignedUsers,
                  'system': e.system,
                })
            .toList(),
        'base_roles': catalog.baseRoles
            .map((e) => {
                  'name': e.name,
                  'title': e.title,
                  'description': e.description,
                  'available': e.available
                })
            .toList(),
        'templates': <dynamic>[],
        'template_categories': <dynamic>[],
      };
}

/// Same catalog as [_RoleClient] but the signed-in user is an HR Manager, who
/// can read the role catalog yet cannot manage roles (`canManageRoles` is
/// false), so the summary sheet must hide the edit action.
class _HrClient extends _RoleClient {
  _HrClient(super.catalog);

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'hr@asoud-demo.local',
        fullName: 'مدیر منابع انسانی',
        roles: const ['HR Manager'],
      );
}

const _catalog = RoleCatalog(
  categories: [
    RoleCategory(code: 'FIN', title: 'مالی', style: 'finance'),
    RoleCategory(code: 'HR', title: 'منابع انسانی', style: 'hr'),
  ],
  roles: [
    ManagedRole(
      code: 'ACCOUNTANT',
      title: 'حسابدار',
      category: 'FIN',
      baseRoles: ['Accounts User'],
      description: 'نقش مالی نمونه',
      assignedUsers: 3,
      modified: '2026-01-01 00:00:00',
      profileModified: '2026-01-01 00:00:00',
    ),
    ManagedRole(
      code: 'SYS_ROLE',
      title: 'نقش سیستمی نمونه',
      category: 'HR',
      baseRoles: [],
      system: true,
      modified: '2026-01-01 00:00:00',
      profileModified: '2026-01-01 00:00:00',
    ),
  ],
  baseRoles: [
    BaseAccessRole(
        name: 'Accounts User',
        title: 'کاربر حسابداری',
        description: '',
        available: true),
  ],
);

Future<void> _openList(WidgetTester tester, double width,
    {required _RoleClient client}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
  await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
  await tester.pumpAndSettle();
}

Finder _sheetText(String text) => find.descendant(
    of: find.byKey(const Key('role_summary_sheet')), matching: find.text(text));

/// Role rows are rendered only inside an expanded category, so the test must
/// open the category before it can tap the role.
Future<void> _expandCategory(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('role summary sheet shows the real values of the role',
      (tester) async {
    final client = _RoleClient(_catalog);
    await _openList(tester, 390, client: client);

    await _expandCategory(tester, 'مالی');
    await tester.tap(find.text('حسابدار'));
    await tester.pumpAndSettle();

    expect(_sheetText('حسابدار'), findsOneWidget);
    expect(_sheetText('نقش مالی نمونه'), findsOneWidget);
    expect(_sheetText('مالی'), findsOneWidget);
    expect(_sheetText('فعال'), findsOneWidget);
    expect(_sheetText('۳ کاربر'), findsOneWidget);
    expect(_sheetText('کاربر حسابداری'), findsOneWidget);
    expect(_sheetText('نقش سیستمی'), findsNothing);
    expect(_sheetText('جزئیات و دسترسی‌ها'), findsOneWidget);
    expect(_sheetText('کاربران اختصاص‌یافته'), findsOneWidget);
    expect(_sheetText('ویرایش مشخصات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-manager sees no edit action in the role summary sheet',
      (tester) async {
    // HR Manager can read the catalog but cannot manage roles.
    final client = _HrClient(_catalog);
    await _openList(tester, 390, client: client);

    await _expandCategory(tester, 'مالی');
    await tester.tap(find.text('حسابدار'));
    await tester.pumpAndSettle();

    // The sheet is open; a non-manager (canManage == false) has no edit entry.
    expect(_sheetText('جزئیات و دسترسی‌ها'), findsOneWidget);
    expect(_sheetText('کاربران اختصاص‌یافته'), findsOneWidget);
    expect(_sheetText('ویرایش مشخصات'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a system role shows the badge and no edit action',
      (tester) async {
    final client = _RoleClient(_catalog);
    await _openList(tester, 390, client: client);

    await _expandCategory(tester, 'منابع انسانی');
    await tester.tap(find.text('نقش سیستمی نمونه'));
    await tester.pumpAndSettle();

    expect(_sheetText('نقش سیستمی'), findsOneWidget);
    expect(_sheetText('بدون مجوز'), findsOneWidget);
    expect(_sheetText('ویرایش مشخصات'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing only the category keeps the base roles in the save',
      (tester) async {
    final client = _RoleClient(_catalog);
    await _openList(tester, 390, client: client);

    await _expandCategory(tester, 'مالی');
    await tester.tap(find.text('حسابدار'));
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('ویرایش مشخصات'));
    await tester.pumpAndSettle();

    // Open the category picker and switch from مالی to منابع انسانی.
    await tester.tap(find.byKey(const ValueKey('category-FIN')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منابع انسانی'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(client.savedPayloads, hasLength(1));
    final payload = client.savedPayloads.first;
    expect(payload['category'], 'HR');
    expect(payload['base_roles'], ['Accounts User']);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'role summary sheet fits a 60-character Persian title at ${width.toInt()} px',
        (tester) async {
      final catalog = RoleCatalog(
        categories: [
          RoleCategory(code: 'FIN', title: 'مالی', style: 'finance'),
        ],
        roles: [
          ManagedRole(
            code: 'LONG',
            title: _longTitle,
            category: 'FIN',
            baseRoles: const [],
            description: '',
            assignedUsers: 0,
          ),
        ],
      );
      final client = _RoleClient(catalog);
      await _openList(tester, width, client: client);

      await _expandCategory(tester, 'مالی');
      await tester.tap(find.text(_longTitle));
      await tester.pumpAndSettle();

      expect(_sheetText(_longTitle), findsOneWidget);
      expect(_sheetText('بدون مجوز'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
