import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/organization_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_local_record_store.dart';

class _RealBackendShapeClient extends Fake implements FrappeApiClient {
  _RealBackendShapeClient({
    this.userId = 'Administrator',
    this.userRoles = const ['Administrator'],
  });

  final String userId;
  final List<String> userRoles;
  final calls = <String>[];

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: userId,
        fullName: 'Administrator',
        roles: userRoles,
      );

  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    calls.add(method);
    if (method == 'asoud_erp.api.v1.role_management.catalog') {
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': {
            'categories': [
              {'code': 'MANAGERS', 'title': 'مدیران', 'style': 'managers'},
              {
                'code': 'FINANCE',
                'title': 'مالی و حسابداری',
                'style': 'finance'
              },
            ],
            'roles': [
              {
                'code': 'SYS_ADMIN',
                'title': 'مدیر سیستم',
                'category': 'MANAGERS',
                'parent': '',
                'description': 'دسترسی کامل مدیریتی',
                'enabled': true,
                'profile': 'ASOUD:SYS_ADMIN',
                'base_roles': ['System Manager'],
                'modified': '2026-10-09 17:18:20.825763',
                'profile_modified': '2026-10-09 17:18:20.825763',
                'assigned_users': 1,
              },
              {
                'code': 'FIN_MGR',
                'title': 'مدیر مالی',
                'category': 'FINANCE',
                'parent': 'SYS_ADMIN',
                'description': 'مدیریت امور مالی',
                'enabled': 1,
                'profile': 'ASOUD:FIN_MGR',
                'base_roles': ['Accounts Manager'],
                'modified': '2026-10-09 17:18:20.825763',
                'profile_modified': '2026-10-09 17:18:20.825763',
                'assigned_users': 2,
              },
            ],
            'base_roles': [
              {
                'name': 'System Manager',
                'title': 'مدیر سیستم',
                'description': 'مدیریت سراسری سامانه',
                'available': true,
              },
              {
                'name': 'Accounts Manager',
                'title': 'مدیر مالی',
                'description': 'مدیریت مالی',
                'available': true,
              },
            ],
            'templates': [
              {
                'code': 'SYSTEM_ADMIN',
                'title': 'مدیر سیستم',
                'category': 'SYSTEM',
                'base_roles': ['System Manager'],
                'available': true,
                'exists': true,
              },
            ],
            'template_categories': [
              {'code': 'MANAGERS', 'title': 'مدیران', 'style': 'managers'},
              {'code': 'SYSTEM', 'title': 'مدیریت سیستم', 'style': 'system'},
            ],
          },
        },
      };
    }

    if (method == 'asoud_erp.api.v1.organization.get_chart') {
      return {
        'message': {
          'ok': true,
          'meta': {'api_version': 'v1'},
          'data': {
            'rows': [
              {
                'code': 'CEO',
                'title': 'مدیرعامل',
                'parent': '',
                'department': 'مدیریت',
                'employee': 'EMP-001',
              },
              {
                'code': 'CTO',
                'title': 'مدیر فنی',
                'parent': 'CEO',
                'department': 'فنی',
                'employee': 'EMP-002',
              },
            ],
            'revision': 1,
            'warnings': <dynamic>[],
          },
        },
      };
    }

    throw StateError('Unexpected method: $method');
  }
}

void main() {
  test('RoleRepository loads catalog with real backend response shape',
      () async {
    final client = _RealBackendShapeClient();
    final store = FakeLocalRecordStore();
    final repository = RoleRepository(client, local: store);
    addTearDown(repository.dispose);

    final catalog = await repository.load();

    expect(catalog.categories, hasLength(2));
    expect(catalog.roles, hasLength(2));
    expect(catalog.roles.first.code, 'SYS_ADMIN');
    expect(catalog.roles.first.enabled, isTrue);
    expect(catalog.roles[1].code, 'FIN_MGR');
    expect(catalog.roles[1].enabled, isTrue);
    expect(catalog.roles[1].assignedUsers, 2);
    expect(catalog.baseRoles, hasLength(2));
    expect(catalog.templates, hasLength(1));
  });

  testWidgets(
      'RolesPage renders non-empty category and role counts from real backend shape',
      (tester) async {
    final client = _RealBackendShapeClient();
    final store = FakeLocalRecordStore();
    final repository = RoleRepository(client, local: store);
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

    expect(find.text('۲ دسته · ۲ نقش'), findsOneWidget);
    expect(find.text('0 دسته · 0 نقش'), findsNothing);

    await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('مدیران'), findsOneWidget);
    expect(find.text('مالی و حسابداری'), findsOneWidget);
    expect(
        find.text(
            'هنوز دسته یا نقشی ثبت نشده است؛ از الگوهای آماده استفاده کنید یا ابتدا یک دسته بسازید.'),
        findsNothing);
  });

  test(
      'OrganizationRepository allows Administrator and parses real get_chart shape',
      () async {
    final client = _RealBackendShapeClient(
      userId: 'Administrator',
      userRoles: const ['Administrator'],
    );
    final store = FakeLocalRecordStore();
    final repository = OrganizationRepository(client, local: store);
    addTearDown(repository.dispose);

    final snapshot = await repository.load('شرکت نمونه آسود');

    expect(snapshot.rows, hasLength(2));
    expect(snapshot.rows.first.code, 'CEO');
    expect(snapshot.rows.first.title, 'مدیرعامل');
    expect(snapshot.rows[1].code, 'CTO');
    expect(snapshot.rows[1].title, 'مدیر فنی');
    expect(snapshot.revision, 1);
  });

  testWidgets(
      'OrganizationPage displays positions for Administrator instead of empty state',
      (tester) async {
    final client = _RealBackendShapeClient(
      userId: 'Administrator',
      userRoles: const ['Administrator'],
    );
    final store = FakeLocalRecordStore();
    final repository = OrganizationRepository(client, local: store);
    addTearDown(repository.dispose);

    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: OrganizationPage(
            company: 'شرکت نمونه آسود',
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مشاهده و تکمیل ساختار سازمانی'));
    await tester.pumpAndSettle();

    expect(find.text('مدیرعامل'), findsOneWidget);
    expect(find.text('جایگاهی برای نمایش وجود ندارد.'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('HR Manager roles page stays read-only at $width without overflow',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _RealBackendShapeClient(
        userId: 'hr-manager@asoud-demo.local',
        userRoles: const ['HR Manager', 'Employee'],
      );
      final store = FakeLocalRecordStore();
      final repository = RoleRepository(client, local: store);
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

      expect(find.text('۲ دسته · ۲ نقش'), findsOneWidget);
      expect(find.text('ایجاد نقش دستی'), findsNothing);
      expect(find.text('ایجاد دسته'), findsNothing);
      expect(find.text('ورود از اکسل'), findsNothing);
      expect(find.text('استفاده از قالب آماده'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'HR Manager sees the role catalog read-only without any create control',
      (tester) async {
    final client = _RealBackendShapeClient(
      userId: 'hr-manager@asoud-demo.local',
      userRoles: const ['HR Manager', 'Employee'],
    );
    final store = FakeLocalRecordStore();
    final repository = RoleRepository(client, local: store);
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

    expect(find.text('۲ دسته · ۲ نقش'), findsOneWidget);
    expect(find.text('ایجاد نقش دستی'), findsNothing);
    expect(find.text('ایجاد دسته'), findsNothing);
    expect(find.text('ورود از اکسل'), findsNothing);
    expect(find.text('استفاده از قالب آماده'), findsNothing);

    await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('مدیران'), findsOneWidget);
    expect(find.text('مالی و حسابداری'), findsOneWidget);
    expect(find.text('ایجاد نقش'), findsNothing);
    expect(find.text('الگوهای موجود'), findsNothing);
    expect(find.text('ایجاد دسته'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'HR Manager browses the organization chart without create or import',
      (tester) async {
    final client = _RealBackendShapeClient(
      userId: 'hr-manager@asoud-demo.local',
      userRoles: const ['HR Manager', 'Employee'],
    );
    final store = FakeLocalRecordStore();
    final repository = OrganizationRepository(client, local: store);
    addTearDown(repository.dispose);

    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: OrganizationPage(
            company: 'شرکت نمونه آسود',
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('استفاده از قالب آماده'), findsNothing);
    expect(find.text('ایجاد ساختار دستی'), findsNothing);
    expect(find.text('ورود از اکسل'), findsNothing);

    await tester.tap(find.text('مشاهده و تکمیل ساختار سازمانی'));
    await tester.pumpAndSettle();

    expect(find.text('مدیرعامل'), findsOneWidget);
    expect(find.text('جایگاهی برای نمایش وجود ندارد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an employee reaching the role pages gets a Persian denial state',
      (tester) async {
    final client = _RealBackendShapeClient(
      userId: 'employee@asoud-demo.local',
      userRoles: const ['Employee'],
    );
    final store = FakeLocalRecordStore();
    final repository = RoleRepository(client, local: store);
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

    expect(find.text('دسترسی ندارید'), findsWidgets);
    expect(find.text('بازگشت'), findsOneWidget);
    expect(find.text('۲ دسته · ۲ نقش'), findsNothing);
    expect(client.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'an employee reaching the organization page gets a Persian denial state',
      (tester) async {
    final client = _RealBackendShapeClient(
      userId: 'employee@asoud-demo.local',
      userRoles: const ['Employee'],
    );
    final store = FakeLocalRecordStore();
    final repository = OrganizationRepository(client, local: store);
    addTearDown(repository.dispose);

    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: OrganizationPage(
            company: 'شرکت نمونه آسود',
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('دسترسی ندارید'), findsWidgets);
    expect(find.text('بازگشت'), findsOneWidget);
    expect(client.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
