import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/create_form_page.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';

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

  testWidgets(
      'صفحه ایجاد فرم جدید کلیه بخش‌های مشخصات و آیکون را به‌درستی رندر می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();
    final repo = FormRepository(client, 'شرکت داده‌پردازی آسود');

    await tester.pumpWidget(_wrap(
      CreateFormPage(
        repository: repo,
        selectedModule: 'HR',
        initialKind: 'Request',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    // Headers
    expect(find.text('ایجاد فرم جدید'), findsOneWidget);
    expect(find.text('طراحی قالب خام'), findsOneWidget);

    // Section 1: Initial Specifications
    expect(find.text('مشخصات اولیه قالب'), findsOneWidget);
    expect(find.text('نوع قالب *'), findsOneWidget);
    expect(find.text('درخواست'), findsOneWidget);
    expect(find.text('سند'), findsOneWidget);

    // Module Card
    expect(find.text('ماژول انتخاب‌شده'), findsOneWidget);
    expect(find.text('منابع انسانی'), findsOneWidget);
    expect(find.text('انتخاب‌شده از صفحه قبل'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    // Creation Methods
    expect(find.text('روش ایجاد قالب *'), findsOneWidget);
    expect(find.text('طراحی فرم جدید'), findsOneWidget);
    expect(find.text('استفاده از الگوی آماده'), findsOneWidget);

    // Choose Ready Template
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();

    expect(find.text('الگوی آماده'), findsOneWidget);
    expect(find.text('برای انتخاب الگو لمس کنید...'), findsOneWidget);

    // Open template picker sheet
    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب الگوی آماده'), findsOneWidget);
    expect(find.text('نام الگو را جست‌وجو کنید...'), findsOneWidget);
    expect(find.text('درخواست مرخصی'), findsOneWidget);

    // Pick template
    await tester.tap(find.text('درخواست مرخصی'));
    await tester.pumpAndSettle();

    // Verify template was selected and title populated
    expect(find.text('کپی درخواست مرخصی'), findsOneWidget);

    // Section 2: Icon and Color
    await tester.scrollUntilVisible(
      find.text('انتخاب آیکون فرم'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('انتخاب آیکون فرم'), findsOneWidget);
    expect(find.text('کتابخانه آیکون‌ها'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('رنگ آیکون'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('رنگ آیکون'), findsOneWidget);

    // Toggle icons expansion
    await tester.scrollUntilVisible(
      find.text('نمایش همه'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('نمایش همه'));
    await tester.pumpAndSettle();
    expect(find.text('نمایش کمتر'), findsOneWidget);

    // Submit button (located in bottomNavigationBar, always on screen)
    expect(find.text('تأیید و ادامه'), findsOneWidget);
    await tester.tap(find.text('تأیید و ادامه'));
    await tester.pumpAndSettle();

    // Should navigate to FormEditorPage
    expect(find.byType(FormEditorPage), findsOneWidget);
  });

  testWidgets(
      'ورود از دکمه ایجاد فرم در حالت همه ماژول‌ها شیت انتخاب ماژول را باز می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();

    await tester.pumpWidget(_wrap(
      const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    // Tap '+ ایجاد فرم جدید' when 'همه' is selected
    await tester.tap(find.text('+ ایجاد فرم جدید'));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب ماژول'), findsOneWidget);
    expect(find.text('برای ایجاد فرم جدید، ابتدا ماژول مربوطه را مشخص کنید.'),
        findsOneWidget);

    // Tap module 'مالی' and continue
    await tester.tap(find.text('مالی').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // Verify we arrived at CreateFormPage with 'مالی'
    expect(find.byType(CreateFormPage), findsOneWidget);
    expect(find.text('مالی'), findsOneWidget);
  });

  testWidgets('صفحه ایجاد فرم جدید در عرض ۳۲۰ بدون سرریز رندر می‌شود',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();
    final repo = FormRepository(client, 'شرکت داده‌پردازی آسود');

    await tester.pumpWidget(_wrap(
      CreateFormPage(
        repository: repo,
        selectedModule: 'Purchase',
        initialKind: 'Document',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ایجاد فرم جدید'), findsOneWidget);
    expect(find.text('مشخصات اولیه قالب'), findsOneWidget);
  });
}
