import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
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

/// Encodes a catalog for the `role_management.catalog` response, letting the
/// caller override the category list (used to place a new category first).
Map<String, dynamic> _encodeCatalog(
    RoleCatalog catalog, List<RoleCategory> categories) =>
    {
      'categories': categories
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
        'data': _encodeCatalog(catalog, catalog.categories),
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

/// Serves the catalog and, once a category is created, prepends the new
/// category to the list it serves (first, not last). This lets the role form's
/// "select the newly created category" logic be exercised against a
/// server-shaped response where the new category is not the last element.
class _CategoryCreateClient extends Fake implements FrappeApiClient {
  _CategoryCreateClient(this.catalog, this.categories);
  final RoleCatalog catalog;
  final List<RoleCategory> categories;
  final createdCategories = <Map<String, dynamic>>[];

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
        'data': _encodeCatalog(catalog, categories),
      },
    };
  }

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method != 'asoud_erp.api.v1.role_management.create_category') {
      throw StateError('Unexpected asoud method: $method');
    }
    final payload =
        Map<String, dynamic>.from((data?['payload'] ?? {}) as Map);
    createdCategories.add(payload);
    // The server now knows the category; it appears first in the catalog.
    categories.insert(
        0,
        RoleCategory(
            code: '${payload['code']}',
            title: '${payload['title']}',
            style: '${payload['style']}'));
    return {
      'code': payload['code'],
      'title': payload['title'],
      'style': payload['style'],
    };
  }
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
    {required FrappeApiClient client}) async {
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

  testWidgets('creating a category from the form selects the new category',
      (tester) async {
    // The new category is placed FIRST in the post-create catalog response, so
    // picking it cannot be done by taking the last element of the list.
    final client = _CategoryCreateClient(
      _catalog,
      [
        RoleCategory(code: 'FIN', title: 'مالی', style: 'finance'),
        RoleCategory(code: 'HR', title: 'منابع انسانی', style: 'hr'),
      ],
    );
    await _openList(tester, 390, client: client);

    await _expandCategory(tester, 'مالی');
    await tester.tap(find.text('حسابدار'));
    await tester.pumpAndSettle();
    await tester.tap(_sheetText('ویرایش مشخصات'));
    await tester.pumpAndSettle();

    // Open the category form from the role form.
    await tester.tap(find.text('دسته جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is AppTextField && w.label == 'نام دسته'),
        'دسته تازه');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is AppTextField && w.label == 'کد دسته'),
        'OPS');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ایجاد دسته'));
    await tester.pumpAndSettle();

    // The form's category field now shows the newly created category title.
    expect(find.text('دسته تازه'), findsOneWidget);
    expect(client.createdCategories, hasLength(1));
    expect(client.createdCategories.first['code'], 'OPS');
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
