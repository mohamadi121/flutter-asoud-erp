import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/data/account_repository.dart';
import 'package:asoud_erp/features/auth/domain/entities/authenticated_user.dart';
import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';
import 'package:asoud_erp/features/auth/domain/repositories/auth_repository.dart';
import 'package:asoud_erp/features/auth/presentation/pages/account_security_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/admin_profile_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/change_password_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/post_login_page.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_account_repository.dart';
import '../../helpers/fake_office_repository.dart';

class _Client implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements AuthRepository {
  int signOuts = 0;
  @override
  bool get isAuthenticated => true;
  @override
  Future<AuthenticatedUser> getCurrentUser() async =>
      const AuthenticatedUser(id: 'u', fullName: 'u', roles: {});
  @override
  Future<AuthenticatedUser> signIn(
          {required String username, required String password}) async =>
      getCurrentUser();
  @override
  Future<void> signOut() async => signOuts++;
}

Widget _app(FakeAccountRepository accounts, _Auth auth, Widget home) =>
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: _Client()),
        RepositoryProvider<AuthRepository>.value(value: auth),
        RepositoryProvider<AccountRepository>.value(value: accounts),
        RepositoryProvider<OfficeRepository>.value(
            value: FakeOfficeRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    );

LoginState _s({
  bool temp = false,
  bool admin = false,
  bool create = false,
  bool done = false,
  List<String> offices = const [],
}) =>
    LoginState(
      userId: 'owner@acme.ir',
      mustChangePassword: temp,
      isSystemAdmin: admin,
      canCreateOffice: create,
      adminProfileComplete: done,
      offices: [for (final o in offices) OfficeRef(name: o, title: 'دفتر $o')],
    );

Future<void> _route(WidgetTester tester, LoginState state) async {
  final accounts = FakeAccountRepository(
      state: state, profile: const AccountProfile(username: 'owner@acme.ir'));
  await tester.pumpWidget(_app(accounts, _Auth(), const PostLoginPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('temporary password forces the change screen without a way back',
      (tester) async {
    await _route(tester, _s(temp: true, admin: true, create: true));
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.text('بازگشت بدون تغییر'), findsNothing);
  });

  testWidgets('admin with no office is sent to create the first office',
      (tester) async {
    await _route(tester, _s(admin: true, create: true, done: true));
    expect(find.byType(OfficeFormPage), findsOneWidget);
  });

  testWidgets('admin with an office but no profile sees the profile form',
      (tester) async {
    await _route(tester, _s(admin: true, create: true, offices: ['A']));
    expect(find.byType(AdminProfilePage), findsOneWidget);
    expect(find.text('owner@acme.ir'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('first Administrator login opens profile before office at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _route(tester, LoginState(
        userId: 'Administrator',
        isSystemAdmin: true,
        canCreateOffice: true,
        adminProfileComplete: false,
        next: const NextRoute(route: 'create-first-office'),
      ));
      expect(find.byType(AdminProfilePage), findsOneWidget);
      expect(find.byType(OfficeFormPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('personnel without an office sees the exact message only',
      (tester) async {
    await _route(tester, _s());
    expect(find.text('هنوز دسترسی به دفتر کاری برای شما تعیین نشده است.'),
        findsOneWidget);
    expect(find.byType(OfficeFormPage), findsNothing);
    expect(find.byType(AdminProfilePage), findsNothing);
    expect(find.textContaining('ایجاد'), findsNothing);
  });

  testWidgets('personnel with an office never sees onboarding screens',
      (tester) async {
    await _route(tester, _s(offices: ['A']));
    expect(find.byType(OfficeFormPage), findsNothing);
    expect(find.byType(AdminProfilePage), findsNothing);
    expect(find.byType(ChangePasswordPage), findsNothing);
  });

  testWidgets('several offices without a remembered one ask which', (tester) async {
    final accounts =
        FakeAccountRepository(state: _s(offices: ['A', 'B']));
    await tester.pumpWidget(_app(accounts, _Auth(), const PostLoginPage()));
    await tester.pumpAndSettle();
    expect(find.byType(OfficePickerPage), findsOneWidget);
    expect(find.text('دفتر A'), findsOneWidget);
    expect(find.text('دفتر B'), findsOneWidget);
  });

  testWidgets('no-office screen signs out to the login with the server kept',
      (tester) async {
    final auth = _Auth();
    final accounts = FakeAccountRepository(state: _s());
    await tester.pumpWidget(_app(accounts, auth, const PostLoginPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خروج از حساب'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('account security opens the very same change-password screen',
      (tester) async {
    final accounts = FakeAccountRepository();
    await tester
        .pumpWidget(_app(accounts, _Auth(), const AccountSecurityPage()));
    await tester.tap(find.byKey(const Key('security_change_password')));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('current_password')), 'old-password-123');
    await tester.enterText(
        find.byKey(const Key('new_password')), 'brand-new-password');
    await tester.enterText(
        find.byKey(const Key('repeat_password')), 'brand-new-password');
    await tester.tap(find.text('ثبت رمز جدید'));
    await tester.pumpAndSettle();
    expect(accounts.changeCalls, 1);
  });
}
