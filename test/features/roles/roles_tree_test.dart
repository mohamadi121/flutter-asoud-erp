import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/roles/data/role_repository.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements RoleRepository {}

class _HrManagerClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
      userId: 'hr@asoud.local', fullName: 'HR', roles: ['HR Manager']);
}

/// A catalog with completion data: 3 managed roles (A complete, B incomplete,
/// C complete-but-uncategorized), 2 categories, and a system admin row.
RoleCatalog _catalog() => RoleCatalog(
      categories: [
        RoleCategory(code: 'MANAGERS', title: 'مدیران', style: 'managers'),
        RoleCategory(
            code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance'),
      ],
      roles: [
        ManagedRole(
            code: 'A',
            title: 'مدیر مالی',
            category: 'FINANCE',
            baseRoles: ['Accounts Manager'],
            completion: 'complete'),
        ManagedRole(
            code: 'B',
            title: 'حسابدار',
            category: 'FINANCE',
            baseRoles: const [],
            description: 'ثبت اسناد مالی',
            completion: 'incomplete'),
        ManagedRole(
            code: 'C',
            title: 'نقش بدون دسته',
            category: '',
            baseRoles: const [],
            completion: 'complete'),
      ],
      systemRoles: [
        ManagedRole(
            code: 'SYSTEM_ADMIN',
            title: 'مدیر کل سیستم',
            category: '',
            baseRoles: const [],
            system: true,
            scope: 'global',
            scopeTitle: 'سراسری'),
      ],
      summary: const RoleCatalogSummary(
          roles: 3, categories: 2, uncategorized: 1, incomplete: 1),
    );

Future<void> _pump(WidgetTester tester, RoleRepository repository,
    {double width = 390,
    bool openList = true,
    FrappeApiClient? capabilitiesClient}) async {
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  when(() => repository.sessionChanges)
      .thenAnswer((_) => const Stream<bool>.empty());
  when(() => repository.dispose()).thenAnswer((_) async {});
  when(() => repository.offline).thenReturn(false);
  when(() => repository.isPreview).thenReturn(false);
  when(() => repository.pendingCount).thenReturn(0);
  when(() => repository.isDraft(any())).thenReturn(false);
  final page = RolesPage(repository: repository);
  await tester.pumpWidget(capabilitiesClient == null
      ? MaterialApp(home: page)
      : RepositoryProvider<FrappeApiClient>.value(
          value: capabilitiesClient, child: MaterialApp(home: page)));
  await tester.pumpAndSettle();
  if (openList) {
    await tester.tap(find.text('مشاهده و تکمیل نقش‌ها'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('stat cards show the real counts from the catalog',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository);
    expect(
        find.descendant(
            of: find.byKey(const Key('stat_card_roles')),
            matching: find.text('۳')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('stat_card_categories')),
            matching: find.text('۲')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('stat_card_incomplete')),
            matching: find.text('۱')),
        findsOneWidget);
    expect(find.text('کل نقش‌ها'), findsOneWidget);
    expect(find.text('دسته‌بندی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'an older server without completion data hides the third card, the filter and the row labels',
      (tester) async {
    final repository = _Repository();
    // No `completion` key anywhere and no `summary.incomplete`.
    when(() => repository.load()).thenAnswer((_) async => RoleCatalog(
        categories: [
          RoleCategory(code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance')
        ],
        roles: [
          ManagedRole(
              code: 'A',
              title: 'مدیر مالی',
              category: 'FINANCE',
              baseRoles: const ['Accounts Manager'])
        ]));
    await _pump(tester, repository);
    expect(find.byKey(const Key('stat_card_incomplete')), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('نیازمند تکمیل'), findsNothing);
    expect(find.text('تکمیل‌شده'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search matches a role description', (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField), 'ثبت اسناد');
    await tester.pumpAndSettle();
    expect(find.text('حسابدار'), findsOneWidget);
    expect(find.text('مدیر مالی'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search matches a category title', (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField), 'حسابداری');
    await tester.pumpAndSettle();
    // Both FINANCE roles appear because the category title matches.
    expect(find.text('مدیر مالی'), findsOneWidget);
    expect(find.text('حسابدار'), findsOneWidget);
    expect(find.text('نقش بدون دسته'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the incomplete filter shows only incomplete roles',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository);
    await tester.tap(find.descendant(
        of: find.byType(ChoiceChip), matching: find.text('نیازمند تکمیل')));
    await tester.pumpAndSettle();
    expect(find.text('حسابدار'), findsOneWidget);
    expect(find.text('مدیر مالی'), findsNothing);
    expect(find.text('نقش بدون دسته'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a status filter keeps a matching child visible when its parent is filtered out',
      (tester) async {
    // P is complete, C is incomplete and a child of P. The incomplete filter
    // removes P, so C becomes a tree root and must still be shown.
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => RoleCatalog(
        categories: [
          RoleCategory(
              code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance')
        ],
        roles: [
          ManagedRole(
              code: 'P',
              title: 'نقش والد',
              category: 'FINANCE',
              baseRoles: const ['System Manager'],
              completion: 'complete'),
          ManagedRole(
              code: 'C',
              title: 'نقش فرزند',
              category: 'FINANCE',
              parent: 'P',
              baseRoles: const [],
              completion: 'incomplete'),
        ],
        summary: const RoleCatalogSummary(
            roles: 2, categories: 1, uncategorized: 0, incomplete: 1)));
    await _pump(tester, repository);
    await tester.tap(find.descendant(
        of: find.byType(ChoiceChip), matching: find.text('نیازمند تکمیل')));
    await tester.pumpAndSettle();
    expect(find.text('نقش فرزند'), findsOneWidget);
    expect(find.text('نقش والد'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a status filter keeps a matching child visible under a collapsed matching parent',
      (tester) async {
    // Both P and C are incomplete. P matches the filter but is collapsed, so
    // C (a matching child) must still be rendered under it.
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => RoleCatalog(
        categories: [
          RoleCategory(
              code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance')
        ],
        roles: [
          ManagedRole(
              code: 'P',
              title: 'نقش والد',
              category: 'FINANCE',
              baseRoles: const [],
              completion: 'incomplete'),
          ManagedRole(
              code: 'C',
              title: 'نقش فرزند',
              category: 'FINANCE',
              parent: 'P',
              baseRoles: const [],
              completion: 'incomplete'),
        ],
        summary: const RoleCatalogSummary(
            roles: 2, categories: 1, uncategorized: 0, incomplete: 2)));
    await _pump(tester, repository);
    await tester.tap(find.descendant(
        of: find.byType(ChoiceChip), matching: find.text('نیازمند تکمیل')));
    await tester.pumpAndSettle();
    expect(find.text('نقش فرزند'), findsOneWidget);
    expect(find.text('نقش والد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a collapsed category still yields its roles to a search',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository);
    // Expand then collapse the FINANCE category so it is not open.
    await tester.tap(find.text('حسابداری و مالی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابداری و مالی'));
    await tester.pumpAndSettle();
    // Search a term that only matches the role's description, not the
    // category title, so the hit must come from inside the collapsed group.
    await tester.enterText(find.byType(TextField), 'ثبت اسناد');
    await tester.pumpAndSettle();
    expect(find.text('حسابدار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  RoleCatalog parentChildCatalog() => RoleCatalog(
        categories: [
          RoleCategory(
              code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance')
        ],
        roles: [
          ManagedRole(
              code: 'P',
              title: 'نقش والد',
              category: 'FINANCE',
              baseRoles: const ['System Manager'],
              completion: 'complete'),
          ManagedRole(
              code: 'C',
              title: 'نقش فرزند',
              category: 'FINANCE',
              parent: 'P',
              baseRoles: const [],
              completion: 'complete'),
        ],
        summary: const RoleCatalogSummary(
            roles: 2, categories: 1, uncategorized: 0, incomplete: 0),
      );

  testWidgets('tapping a parent row opens the sheet without expanding it',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load())
        .thenAnswer((_) async => parentChildCatalog());
    await _pump(tester, repository);
    await tester.tap(find.text('حسابداری و مالی'));
    await tester.pumpAndSettle();
    // The parent is visible; its child is hidden while the parent is collapsed.
    expect(find.text('نقش والد'), findsOneWidget);
    expect(find.text('نقش فرزند'), findsNothing);
    await tester.tap(find.text('نقش والد'));
    await tester.pumpAndSettle();
    // The sheet opened, but the child is still not expanded.
    expect(find.byKey(const Key('role_summary_sheet')), findsOneWidget);
    expect(find.text('نقش فرزند'), findsNothing);
    await tester.tapAt(const Offset(195, 10)); // above the sheet, on the barrier
    await tester.pumpAndSettle();
    expect(find.text('نقش فرزند'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the expand button expands the role without opening the sheet',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load())
        .thenAnswer((_) async => parentChildCatalog());
    await _pump(tester, repository);
    await tester.tap(find.text('حسابداری و مالی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role_expand_P')));
    await tester.pumpAndSettle();
    // The child is now rendered, but the sheet did not open.
    expect(find.text('نقش فرزند'), findsOneWidget);
    expect(find.byKey(const Key('role_summary_sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty catalog offers the three start actions',
      (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => const RoleCatalog());
    await _pump(tester, repository);
    expect(find.text('نقشی ثبت نشده است'), findsOneWidget);
    expect(find.text('استفاده از قالب آماده'), findsOneWidget);
    expect(find.text('ایجاد نقش جدید'), findsOneWidget);
    expect(find.text('ورود از اکسل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-manager sees no create or add controls', (tester) async {
    final repository = _Repository();
    when(() => repository.load()).thenAnswer((_) async => _catalog());
    await _pump(tester, repository, capabilitiesClient: _HrManagerClient());
    expect(find.text('ایجاد نقش'), findsNothing);
    expect(find.text('الگوهای موجود'), findsNothing);
    expect(find.text('ایجاد دسته'), findsNothing);
    expect(find.text('افزودن نقش به این دسته'), findsNothing);
    // The catalog itself is still readable (category headers remain).
    expect(find.text('حسابداری و مالی'), findsOneWidget);
    expect(find.text('مدیران'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('a 60-character Persian title does not overflow at $width',
        (tester) async {
      final longTitle = 'نقش' * 20; // exactly 60 characters
      final repository = _Repository();
      when(() => repository.load()).thenAnswer((_) async => RoleCatalog(
              categories: [
                RoleCategory(
                    code: 'FINANCE', title: 'حسابداری و مالی', style: 'finance')
              ],
              roles: [
                ManagedRole(
                    code: 'LONG',
                    title: longTitle,
                    category: 'FINANCE',
                    baseRoles: const [],
                    completion: 'complete')
              ],
              summary: const RoleCatalogSummary(
                  roles: 1, categories: 1, uncategorized: 0, incomplete: 0)));
      await _pump(tester, repository, width: width);
      await tester.tap(find.text('حسابداری و مالی'));
      await tester.pumpAndSettle();
      expect(find.text(longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
