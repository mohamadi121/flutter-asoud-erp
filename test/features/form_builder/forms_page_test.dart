import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/auth/access_denied.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';

class _FakeEmployeeClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'employee@asoud.local',
        fullName: 'کارمند ساده',
        roles: ['Employee'],
        company: 'شرکت تست آسود',
      );
}

class _FakeManagerClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager', 'Administrator'],
        company: 'شرکت داده‌پردازی آسود',
      );

  @override
  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    if (method.endsWith('list_forms')) {
      return {
        'message': {
          'ok': true,
          'data': [
            {
              'name': 'FORM-001',
              'title': 'فرم مرخصی استحقاقی',
              'kind': 'Request',
              'module_key': 'HR',
              'status': 'Published',
              'version': 2,
              'draft_version': 2,
              'schema': {
                'title': 'فرم مرخصی استحقاقی',
                'module': 'HR',
              },
            },
          ],
        },
      };
    }
    if (method.endsWith('get_history')) {
      return {
        'message': {
          'ok': true,
          'data': [
            {
              'name': 'REV-001',
              'version': 1,
              'published_on': '2026-03-20T10:00:00Z',
              'published_by': 'admin',
              'change_note': 'نسخه اولیه',
            },
          ],
        },
      };
    }
    return {
      'message': {
        'ok': true,
        'data': <Map<String, dynamic>>[],
      },
    };
  }
}

Widget _wrap(Widget child, FrappeApiClient client) =>
    RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        locale: const Locale('fa'),
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('کاربر فاقد نقش مدیریت فرم صفحه دسترسی ندارید را می‌بیند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
        const VersionedFormsPage(company: 'شرکت تست'), _FakeEmployeeClient()));
    await tester.pumpAndSettle();

    expect(find.byType(AccessDeniedScaffold), findsOneWidget);
  });

  testWidgets(
      'کاربر مجاز صفحه مدیریت فرم‌ها، نام شرکت، جست‌وجوی قالب فرم و منوی نسخه‌ها را می‌بیند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
        const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
        _FakeManagerClient()));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت فرم‌ها'), findsOneWidget);
    expect(find.text('شرکت داده‌پردازی آسود'), findsOneWidget);
    expect(find.text('درخواست‌ها'), findsOneWidget);
    expect(find.text('سندها'), findsOneWidget);

    // Search field hint check
    expect(find.text('جست‌وجوی قالب فرم...'), findsOneWidget);

    // Enter search text and verify clear icon
    await tester.enterText(find.byType(TextField).first, 'مرخصی');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('مرخصی'), findsNothing);

    // 3-dot popup menu check
    final popupMenu = find.byType(PopupMenuButton<String>);
    expect(popupMenu, findsOneWidget);
    await tester.tap(popupMenu);
    await tester.pumpAndSettle();

    expect(find.text('نسخه‌ها'), findsOneWidget);
    expect(find.text('ویرایش / نسخه جدید'), findsOneWidget);
    expect(find.text('ایجاد نسخه مشابه'), findsOneWidget);
    expect(find.text('پیش‌نمایش'), findsOneWidget);

    // Tap versions to open history sheet
    await tester.tap(find.text('نسخه‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('تاریخچه نسخه‌ها'), findsOneWidget);
    expect(find.text('نسخه ۱'), findsOneWidget);
  });

  testWidgets(
      'بخش ماژول‌ها و کارت‌های قالب فرم و وضعیت‌ها به‌درستی نمایش داده می‌شوند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
        const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
        _FakeManagerClient()));
    await tester.pumpAndSettle();

    // Module header and cards
    expect(find.text('ماژول‌ها'), findsOneWidget);
    expect(find.text('نمایش همه'), findsOneWidget);
    expect(find.text('همه'), findsOneWidget);
    expect(find.text('منابع انسانی'), findsAtLeastNWidgets(1));
    expect(find.text('مالی'), findsOneWidget);
    expect(find.text('فروش'), findsOneWidget);
    expect(find.text('انبار'), findsOneWidget);
    expect(find.text('اداری'), findsOneWidget);

    // Expand modules
    await tester.tap(find.text('نمایش همه'));
    await tester.pumpAndSettle();
    expect(find.text('نمایش کمتر'), findsOneWidget);
    expect(find.text('فناوری اطلاعات'), findsOneWidget);
    expect(find.text('تولید'), findsOneWidget);

    // Template section header & card
    expect(find.text('قالب فرم‌های درخواست'), findsOneWidget);
    expect(find.text('۱ مورد'), findsOneWidget);
    expect(find.text('فرم مرخصی استحقاقی'), findsOneWidget);
    expect(find.text('فعال'), findsOneWidget);

    // Filter by another module that has no forms
    await tester.tap(find.text('مالی'));
    await tester.pumpAndSettle();
    expect(find.text('۰ مورد'), findsOneWidget);
    expect(find.text('فرمی با این فیلتر پیدا نشد.'), findsOneWidget);

    // Tap 'همه' to restore
    await tester.tap(find.text('همه'));
    await tester.pumpAndSettle();
    expect(find.text('۱ مورد'), findsOneWidget);
    expect(find.text('فرم مرخصی استحقاقی'), findsOneWidget);
  });

  testWidgets('صفحه مدیریت فرم‌ها در عرض ۳۲۰ بدون سرریز رندر می‌شود',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
        const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
        _FakeManagerClient()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('مدیریت فرم‌ها'), findsOneWidget);
  });
}
