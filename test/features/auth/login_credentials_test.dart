import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/data/account_repository.dart';
import 'package:asoud_erp/features/auth/data/saved_credentials_store.dart';
import 'package:asoud_erp/features/auth/domain/entities/authenticated_user.dart';
import 'package:asoud_erp/features/auth/domain/repositories/auth_repository.dart';
import 'package:asoud_erp/features/auth/domain/server_url_policy.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_account_repository.dart';
import '../../helpers/fake_office_repository.dart';

class _Client implements FrappeApiClient {
  bool authed = false;
  @override
  bool get isAuthenticated => authed;
  @override
  Stream<bool> get authenticationChanges => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements AuthRepository {
  _Auth(this.client, {this.failWith});
  final _Client client;
  final Object? failWith;
  final signIns = <(String, String)>[];
  @override
  bool get isAuthenticated => client.authed;
  @override
  Future<AuthenticatedUser> getCurrentUser() async =>
      const AuthenticatedUser(id: 'u', fullName: 'u', roles: {});
  @override
  Future<AuthenticatedUser> signIn(
      {required String username, required String password}) async {
    signIns.add((username, password));
    if (failWith != null) throw failWith!;
    client.authed = true;
    return getCurrentUser();
  }

  @override
  Future<void> signOut() async => client.authed = false;
}

const _server = 'https://erp.example.com';
const _policy = ServerUrlPolicy(
    requireHttps: true,
    cleartextHosts: '',
    allowedHosts: '',
    buildServer: '');

Widget _app(Widget page, _Client client, _Auth auth,
        {AccountRepository? accounts}) =>
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<AuthRepository>.value(value: auth),
        RepositoryProvider<OfficeRepository>.value(
            value: FakeOfficeRepository()),
        if (accounts != null)
          RepositoryProvider<AccountRepository>.value(value: accounts),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

LoginPage _login(MemoryCredentialVault vault,
        {String? server = _server, bool web = false}) =>
    LoginPage(
      showDemoButton: false,
      initialServerUrl: server,
      urlPolicy: _policy,
      credentials: SavedCredentialsStore(vault: vault, isWeb: web),
    );

Future<void> _fill(WidgetTester tester, String user, String pass) async {
  await tester.enterText(find.byKey(const Key('username_field')), user);
  await tester.pump();
  await tester.enterText(find.byKey(const Key('password_field')), pass);
  await tester.pump();
}

Checkbox _box(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byKey(const Key('remember_password_checkbox')));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('checkbox is off by default and nothing is stored on login',
      (tester) async {
    final vault = MemoryCredentialVault();
    final client = _Client();
    final auth = _Auth(client);
    await tester.pumpWidget(_app(_login(vault), client, auth));
    await tester.pumpAndSettle();
    expect(_box(tester).value, isFalse);
    expect(find.text('ذخیره رمز عبور در این دستگاه'), findsOneWidget);
    await _fill(tester, 'admin1', 'S3cret-pass-1');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(auth.signIns.single, ('admin1', 'S3cret-pass-1'));
    expect(vault.values.values.any((v) => v == 'S3cret-pass-1'), isFalse);
    // last server and username are remembered, the password is not
    expect(vault.values.values, containsAll([_server, 'admin1']));
  });

  testWidgets('ticked box stores the password only in the secure vault',
      (tester) async {
    final vault = MemoryCredentialVault();
    final client = _Client();
    final auth = _Auth(client);
    await tester.pumpWidget(_app(_login(vault), client, auth));
    await tester.pumpAndSettle();
    await _fill(tester, 'admin1', 'S3cret-pass-1');
    await tester.tap(find.byKey(const Key('remember_password_checkbox')));
    await tester.pump();
    expect(_box(tester).value, isTrue);
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(vault.values.values.contains('S3cret-pass-1'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getKeys().any((k) => prefs.get(k).toString().contains('S3cret')),
        isFalse);
  });

  testWidgets('after logout the saved password is prefilled and survives',
      (tester) async {
    final vault = MemoryCredentialVault();
    final store = SavedCredentialsStore(vault: vault);
    await store.rememberServer(_server);
    await store.rememberUsername(_server, 'admin1');
    await store.savePassword(_server, 'admin1', 'S3cret-pass-1');
    final client = _Client();
    final auth = _Auth(client);
    await tester.pumpWidget(_app(_login(vault, server: null), client, auth));
    await tester.pumpAndSettle();
    expect(find.text('admin1'), findsOneWidget);
    expect(_box(tester).value, isTrue);
    final field =
        tester.widget<TextField>(find.byKey(const Key('password_field')));
    expect(field.controller!.text, 'S3cret-pass-1');
    expect(field.obscureText, isTrue);
    expect(await store.readPassword(_server, 'admin1'), 'S3cret-pass-1');
  });

  testWidgets('without opt-in the password field is empty after logout',
      (tester) async {
    final vault = MemoryCredentialVault();
    final store = SavedCredentialsStore(vault: vault);
    await store.rememberUsername(_server, 'admin1');
    final client = _Client();
    await tester
        .pumpWidget(_app(_login(vault), client, _Auth(client)));
    await tester.pumpAndSettle();
    expect(find.text('admin1'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('password_field')))
            .controller!
            .text,
        isEmpty);
    expect(_box(tester).value, isFalse);
  });

  testWidgets('unticking deletes the saved password; clear button too',
      (tester) async {
    final vault = MemoryCredentialVault();
    final store = SavedCredentialsStore(vault: vault);
    await store.rememberUsername(_server, 'admin1');
    await store.savePassword(_server, 'admin1', 'S3cret-pass-1');
    final client = _Client();
    await tester.pumpWidget(_app(_login(vault), client, _Auth(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remember_password_checkbox')));
    await tester.pumpAndSettle();
    expect(await store.readPassword(_server, 'admin1'), isNull);

    await store.savePassword(_server, 'admin1', 'S3cret-pass-1');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_login(vault), client, _Auth(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear_saved_credentials')));
    await tester.pumpAndSettle();
    expect(await store.readPassword(_server, 'admin1'), isNull);
    expect(await store.lastUsername(_server), isNull);
  });

  test('every server+username pair is independent', () async {
    final store = SavedCredentialsStore(vault: MemoryCredentialVault());
    await store.savePassword('https://a.com', 'u1', 'p-a-u1');
    await store.savePassword('https://b.com', 'u1', 'p-b-u1');
    await store.savePassword('https://a.com', 'u2', 'p-a-u2');
    expect(await store.readPassword('https://a.com', 'u1'), 'p-a-u1');
    expect(await store.readPassword('https://b.com', 'u1'), 'p-b-u1');
    await store.deletePassword('https://a.com', 'u1');
    expect(await store.readPassword('https://a.com', 'u1'), isNull);
    expect(await store.readPassword('https://b.com', 'u1'), 'p-b-u1');
    expect(await store.readPassword('https://a.com', 'u2'), 'p-a-u2');
  });

  test('the web never keeps a password; it uses the browser manager',
      () async {
    final vault = MemoryCredentialVault();
    final store = SavedCredentialsStore(vault: vault, isWeb: true);
    expect(store.canStorePassword, isFalse);
    expect(await store.savePassword(_server, 'u', 'pw'), isFalse);
    expect(vault.values, isEmpty);
  });

  testWidgets('a stale saved password is dropped when the server refuses it',
      (tester) async {
    final vault = MemoryCredentialVault();
    final store = SavedCredentialsStore(vault: vault);
    await store.rememberUsername(_server, 'admin1');
    await store.savePassword(_server, 'admin1', 'old-password-123');
    final client = _Client();
    final auth = _Auth(client,
        failWith: const ApiException(
            kind: ApiFailureKind.invalidCredentials,
            message: 'نام کاربری یا رمز عبور نادرست است.'));
    await tester.pumpWidget(_app(_login(vault), client, auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(client.authed, isFalse);
    expect(await store.readPassword(_server, 'admin1'), isNull);
    expect(find.textContaining('دیگر معتبر نیست'), findsOneWidget);
    expect(_box(tester).value, isFalse);
  });

  testWidgets('http server is refused in production and never signs in',
      (tester) async {
    final client = _Client();
    final auth = _Auth(client);
    await tester.pumpWidget(_app(
        _login(MemoryCredentialVault(), server: 'http://evil.example.com'),
        client,
        auth));
    await tester.pumpAndSettle();
    await _fill(tester, 'u', 'p');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(auth.signIns, isEmpty);
    expect(find.textContaining('https'), findsWidgets);
  });

  testWidgets('password can be shown and hidden, username cleared',
      (tester) async {
    final client = _Client();
    await tester.pumpWidget(
        _app(_login(MemoryCredentialVault()), client, _Auth(client)));
    await tester.pumpAndSettle();
    await _fill(tester, 'admin1', 'pw123456789012');
    TextField pw() =>
        tester.widget<TextField>(find.byKey(const Key('password_field')));
    expect(pw().obscureText, isTrue);
    await tester.tap(find.byTooltip('نمایش رمز عبور'));
    await tester.pump();
    expect(pw().obscureText, isFalse);
    await tester.tap(find.byKey(const Key('clear_username')));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('username_field')))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('there is no biometric sign-in', (tester) async {
    final client = _Client();
    await tester.pumpWidget(
        _app(_login(MemoryCredentialVault()), client, _Auth(client)));
    await tester.pumpAndSettle();
    for (final word in ['اثر انگشت', 'تشخیص چهره', 'بیومتریک']) {
      expect(find.textContaining(word), findsNothing);
    }
    for (final icon in [
      Icons.fingerprint,
      Icons.face,
      Icons.face_unlock_outlined,
      Icons.face_retouching_natural,
    ]) {
      expect(find.byIcon(icon), findsNothing);
    }
  });

  testWidgets('forgot-password link calls the recovery service',
      (tester) async {
    final client = _Client();
    final accounts = FakeAccountRepository(recoveryAvailable: true);
    await tester.pumpWidget(_app(
        _login(MemoryCredentialVault()), client, _Auth(client),
        accounts: accounts));
    await tester.pumpAndSettle();
    expect(find.text('رمز عبور خود را فراموش کرده‌اید؟'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('username_field')), 'admin1');
    await tester.tap(find.byKey(const Key('forgot_password_link')));
    await tester.pumpAndSettle();
    expect(find.text('ارسال کد بازیابی'), findsOneWidget);
    await tester.tap(find.text('ارسال کد بازیابی'));
    await tester.pumpAndSettle();
    expect(accounts.resetCalls, 1);
    expect(accounts.lastReset, 'admin1');
    // second step: the one-time code and the new password
    expect(find.byKey(const Key('code_intro')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('code_field')), '123456');
    await tester.enterText(
        find.byKey(const Key('code_new_password')), 'brand-new-password');
    await tester.enterText(
        find.byKey(const Key('code_repeat_password')), 'brand-new-password');
    await tester.tap(find.text('ثبت رمز جدید'));
    await tester.pumpAndSettle();
    expect(accounts.confirmCalls, 1);
    expect(accounts.lastConfirm, {'identifier': 'admin1', 'code': '123456'});
    expect(find.byKey(const Key('reset_done')), findsOneWidget);
  });

  testWidgets('the forgot-password link is hidden when recovery is unavailable',
      (tester) async {
    final client = _Client();
    final accounts = FakeAccountRepository(recoveryAvailable: false);
    await tester.pumpWidget(_app(
        _login(MemoryCredentialVault()), client, _Auth(client),
        accounts: accounts));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot_password_link')), findsNothing);
  });

  testWidgets('invitation activation sends the code and the new password',
      (tester) async {
    final client = _Client();
    final accounts = FakeAccountRepository();
    await tester.pumpWidget(_app(
        _login(MemoryCredentialVault()), client, _Auth(client),
        accounts: accounts));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('activate_account_link')));
    await tester.tap(find.byKey(const Key('activate_account_link')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('code_identifier')), 'new@acme.ir');
    await tester.enterText(find.byKey(const Key('code_field')), 'A1B2C3');
    await tester.enterText(
        find.byKey(const Key('code_new_password')), 'brand-new-password');
    await tester.enterText(
        find.byKey(const Key('code_repeat_password')), 'brand-new-password');
    await tester.tap(find.widgetWithText(FilledButton, 'فعال‌سازی حساب'));
    await tester.pumpAndSettle();
    expect(accounts.activateCalls, 1);
    expect(accounts.lastConfirm, {'identifier': 'new@acme.ir', 'code': 'A1B2C3'});
    expect(find.byKey(const Key('activation_done')), findsOneWidget);
  });

  testWidgets('no dead link: without a recovery service no link is shown',
      (tester) async {
    final client = _Client();
    await tester.pumpWidget(
        _app(_login(MemoryCredentialVault()), client, _Auth(client)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot_password_link')), findsNothing);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('login is RTL, compact and overflow-free at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Client();
      await tester.pumpWidget(_app(
          _login(MemoryCredentialVault()), client, _Auth(client),
          accounts: FakeAccountRepository(recoveryAvailable: true)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(Directionality.of(tester.element(find.byType(LoginPage))),
          TextDirection.rtl);
      for (final key in [
        'server_field',
        'username_field',
        'password_field',
        'remember_password_checkbox',
        'login_button',
        'forgot_password_link',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      expect(find.text('ورود به آسود'), findsOneWidget);
      // normal phone height: nothing to scroll
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.maxScrollExtent, 0);
    });
  }

  testWidgets('with the keyboard open every field stays reachable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.view.resetViewInsets());
    final client = _Client();
    await tester.pumpWidget(_app(
        _login(MemoryCredentialVault()), client, _Auth(client),
        accounts: FakeAccountRepository()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(find.byKey(const Key('login_button')));
    await tester.pump();
    expect(find.byKey(const Key('login_button')), findsOneWidget);
  });
}
