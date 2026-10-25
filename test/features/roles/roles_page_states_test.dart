import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements RoleRepository {}

void main() {
  Future<void> pump(WidgetTester tester, RoleRepository repository) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.sessionChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => repository.offline).thenReturn(false);
    when(() => repository.isPreview).thenReturn(false);
    when(() => repository.pendingCount).thenReturn(0);
    await tester.pumpWidget(
        MaterialApp(home: RolesPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty role catalog explains how to start', (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => const RoleCatalog());
    await pump(tester, repository);
    expect(find.text('نقشی ثبت نشده است'), findsOneWidget);
    expect(find.text('ایجاد نقش'), findsWidgets);
  });

  testWidgets('no role matches the search term', (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => const RoleCatalog(
        categories: [RoleCategory(code: 'c1', title: 'دسته اصلی', style: 'system')]));
    await pump(tester, repository);
    await tester.enterText(find.byType(TextField), 'ناموجود');
    await tester.pumpAndSettle();
    expect(find.text('نتیجه‌ای پیدا نشد'), findsOneWidget);
    expect(find.text('پاک‌کردن جستجو'), findsOneWidget);
    await tester.tap(find.text('پاک‌کردن جستجو'));
    await tester.pumpAndSettle();
    expect(find.text('دسته اصلی'), findsOneWidget);
  });

  testWidgets(
      'the administrator system role is listed as global with full permissions',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => RoleCatalog.fromJson({
          'system_roles': [
            {
              'code': 'SYSTEM_ADMIN',
              'native_role': 'System Manager',
              'title': 'مدیر کل سیستم',
              'scope': 'global',
              'scope_title': 'سراسری',
              'system': true,
              'editable': false,
              'holders': ['owner@acme.ir'],
            }
          ],
          'categories': [
            {'code': 'c1', 'title': 'دسته اصلی', 'style': 'system'}
          ],
        }));
    when(() => repository.systemAdminPermissions()).thenAnswer((_) async =>
        SystemAdminPermissions.fromJson({
          'code': 'SYSTEM_ADMIN',
          'title': 'مدیر کل سیستم',
          'scope': 'global',
          'scope_title': 'سراسری',
          'system': true,
          'capabilities': [
            {
              'key': 'offices.create',
              'module': 'دفترهای کار',
              'title': 'ایجاد دفتر',
              'granted': true
            }
          ],
          'document_permissions': [
            {
              'doctype': 'Employee',
              'actions': ['read', 'write', 'create', 'delete']
            }
          ],
        }));
    await pump(tester, repository);
    expect(find.text('مدیر کل سیستم'), findsOneWidget);
    expect(find.textContaining('سطح دسترسی: سراسری'), findsOneWidget);
    await tester.tap(find.byKey(const Key('system_role_SYSTEM_ADMIN')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capability_offices.create')), findsOneWidget);
    expect(find.text('ایجاد دفتر'), findsOneWidget);
    verify(() => repository.systemAdminPermissions()).called(1);
    verifyNever(() => repository.preview(any()));
  });
}
