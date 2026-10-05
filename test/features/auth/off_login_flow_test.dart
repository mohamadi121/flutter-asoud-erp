import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/data/demo_choice_store.dart';
import 'package:asoud_erp/features/auth/data/demo_transfer_service.dart';
import 'package:asoud_erp/features/auth/domain/entities/authenticated_user.dart';
import 'package:asoud_erp/features/auth/domain/repositories/auth_repository.dart';
import 'package:asoud_erp/features/auth/presentation/pages/demo_transfer_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/login_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/splash_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_local_record_store.dart';
import '../../helpers/fake_office_repository.dart';

class _FakeClient implements FrappeApiClient {
  _FakeClient({this.authenticated = false});

  bool authenticated;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeSession> login(
          {required String username, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'user', fullName: 'کاربر نمونه', roles: ['مدیر سیستم']);

  @override
  Future<List<Map<String, dynamic>>> getResourceList(String doctype,
          {Map<String, dynamic>? queryParameters}) async =>
      [];

  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> callMethod(String method,
          {Map<String, dynamic>? data}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> createResource(
          String doctype, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<dynamic> replayOfflineMutation(
          {required String mutationId,
          required String operation,
          required String target,
          required Map<String, dynamic> data}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateResource(
          String doctype, String name, Map<String, dynamic> data) async =>
      throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.client);

  final _FakeClient client;
  int signOutCalls = 0;
  int signInCalls = 0;

  @override
  bool get isAuthenticated => client.authenticated;

  @override
  Future<AuthenticatedUser> getCurrentUser() async =>
      const AuthenticatedUser(id: 'user', fullName: 'کاربر نمونه', roles: {});

  @override
  Future<AuthenticatedUser> signIn(
      {required String username, required String password}) async {
    signInCalls++;
    client.authenticated = true;
    return getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    client.authenticated = false;
  }
}

Widget _app(Widget page,
    {required _FakeClient client,
    required _FakeAuth auth,
    OfficeRepository? offices}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: client),
      RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<OfficeRepository>.value(
          value: offices ?? FakeOfficeRepository()),
    ],
    child: MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: page),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('splash without session always opens LoginPage', (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        SplashPage(
            restoreSession: () async => false,
            hasDemoChoice: () async => false),
        client: client,
        auth: auth));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('splash with restored session opens the dashboard',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        SplashPage(
            restoreSession: () async => true, hasDemoChoice: () async => false),
        client: client,
        auth: auth));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('remembered demo choice opens the preview directly',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await DemoChoiceStore.setDemoChosen(true);
    await tester.pumpWidget(_app(SplashPage(restoreSession: () async => false),
        client: client, auth: auth));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('login offers the demo entry when the flag value allows it',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(const LoginPage(showDemoButton: true),
        client: client, auth: auth));
    expect(find.text('ورود به نسخه نمایشی (آفلاین)'), findsOneWidget);
    expect(find.text('نام کاربری یا ایمیل'), findsOneWidget);

    await tester.tap(find.text('ورود به نسخه نمایشی (آفلاین)'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(await DemoChoiceStore.isDemoChosen(), isTrue);
  });

  testWidgets('demo entry is hidden when the flag value disables it',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(const LoginPage(showDemoButton: false),
        client: client, auth: auth));
    expect(find.text('ورود به نسخه نمایشی (آفلاین)'), findsNothing);
    expect(find.text('نام کاربری یا ایمیل'), findsOneWidget);
  });

  testWidgets('successful login opens the transfer page when demo data exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'asoud_document_templates_local_v1':
          '[{"name":"LOCAL-TPL-3","title":"سند هزینه","module":"Finance","document_type":"Journal Entry","mapping":{},"status":"Active","company":"دفتر نمونه"}]',
    });
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        LoginPage(
            showDemoButton: true,
            transferService:
                DemoTransferService(store: FakeLocalRecordStore())),
        client: client,
        auth: auth));

    await tester.enterText(
        find.widgetWithText(TextField, 'نام کاربری یا ایمیل'), 'user');
    await tester.enterText(find.widgetWithText(TextField, 'رمز عبور'), 'pass');
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('انتقال داده‌های نسخه نمایشی'), findsOneWidget);
    expect(find.byType(DemoTransferPage), findsOneWidget);
  });

  testWidgets('dashboard preview shows the organization login banner',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true),
        client: client,
        auth: auth));
    expect(find.text('ورود به حساب سازمانی'), findsOneWidget);

    await tester.tap(find.text('ورود به حساب سازمانی').first);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('settings preview offers login, settings session offers logout',
      (tester) async {
    final client = _FakeClient();
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        const SettingsDashboardContent(
            company: 'دفتر نمونه', offlinePreview: true),
        client: client,
        auth: auth));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('ورود به حساب سازمانی'),
        find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('ورود به حساب سازمانی'), findsOneWidget);
    expect(find.text('خروج از حساب'), findsNothing);
  });

  testWidgets(
      'logout confirmation shows the exact unsent count in Persian digits',
      (tester) async {
    final store = FakeLocalRecordStore();
    for (var i = 0; i < 2; i++) {
      await store.save(
          id: 'p$i',
          entityType: 'm',
          payload: const {'operation': 'asoud_method'},
          status: LocalSyncStatus.pendingSync);
    }
    await store.save(
        id: 'f0',
        entityType: 'm',
        payload: const {'operation': 'asoud_method'},
        status: LocalSyncStatus.syncFailed);
    final client = _FakeClient(authenticated: true);
    final auth = _FakeAuth(client);
    await tester.pumpWidget(_app(
        SettingsDashboardContent(
            company: 'دفتر نمونه', offlinePreview: false, offlineStore: store),
        client: client,
        auth: auth));
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 12 && find.text('خروج از حساب').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    final logout = find.text('خروج از حساب');
    expect(logout, findsWidgets);
    await tester.tap(logout.first);
    await tester.pumpAndSettle();

    expect(
        find.textContaining('۳ مورد هنوز به سرور ارسال نشده'), findsOneWidget);
    expect(
        find.text(
            '۳ مورد هنوز به سرور ارسال نشده؛ با خروج، این موارد تا ورود دوباره همین کاربر ارسال نمی‌شوند'),
        findsOneWidget);

    await tester.tap(find.text('خروج'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    // The stack is cleared: nothing to go back to.
    final loginContext = tester.element(find.byType(LoginPage).first);
    expect(Navigator.of(loginContext).canPop(), isFalse);
    // Queued rows survive the logout for the next sign-in.
    expect((await store.list()).length, 3);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('login renders without overflow at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _FakeClient();
      final auth = _FakeAuth(client);
      await tester.pumpWidget(_app(const LoginPage(showDemoButton: true),
          client: client, auth: auth));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ورود به نسخه نمایشی (آفلاین)'), findsOneWidget);
    });

    testWidgets('preview dashboard renders without overflow at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _FakeClient();
      final auth = _FakeAuth(client);
      await tester.pumpWidget(_app(
          const DashboardPage(officeName: 'دفتر نمونه', offlinePreview: true),
          client: client,
          auth: auth));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
