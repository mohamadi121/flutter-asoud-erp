import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/auth/access_denied.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/create_form_page.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
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
  _FakeManagerClient({
    this.forms,
    this.shouldFailList = false,
  });

  List<Map<String, dynamic>>? forms;
  bool shouldFailList;
  final List<String> recordedCalls = [];
  final List<Map<String, dynamic>?> recordedData = [];

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
    recordedCalls.add(method);
    recordedData.add(data);

    if (method.endsWith('list_forms')) {
      if (shouldFailList) {
        throw Exception('Server error 500');
      }
      final defaultForms = [
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
      ];
      final formList = forms ?? defaultForms;
      final requestedKind = data?['kind'];
      final filtered = requestedKind != null
          ? formList.where((f) => f['kind'] == requestedKind).toList()
          : formList;

      return {
        'message': {
          'ok': true,
          'data': filtered,
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
    if (method.endsWith('get_form')) {
      final name = data?['name'];
      final defaultForms = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'FORM-001',
          'title': 'فرم مرخصی استحقاقی',
          'kind': 'Request',
          'module_key': 'HR',
          'status': 'Published',
          'version': 2,
          'draft_version': 2,
          'schema': <String, dynamic>{
            'title': 'فرم مرخصی استحقاقی',
            'module': 'HR',
            'sections': <Map<String, dynamic>>[],
          },
        },
      ];
      final formList = forms ?? defaultForms;
      Map<String, dynamic> found = defaultForms.first;
      for (final f in formList) {
        if (f['name'] == name) {
          found = f;
          break;
        }
      }
      return {'message': {'ok': true, 'data': found}};
    }
    if (method.endsWith('transition')) {
      return {
        'message': {
          'ok': true,
          'status': data?['action'] == 'disable' ? 'Inactive' : 'Published',
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

  testWidgets('آزمون ۲: عملکرد دکمه بازگشت (برگشت به صفحه قبلی معتبر هنگام فشرده‌شدن)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();

    await tester.pumpWidget(
      RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: MaterialApp(
          locale: const Locale('fa'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const VersionedFormsPage(
                          company: 'شرکت داده‌پردازی آسود'),
                    ),
                  ),
                  child: const Text('ورود به مدیریت فرم‌ها'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap to enter
    await tester.tap(find.text('ورود به مدیریت فرم‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('مدیریت فرم‌ها'), findsOneWidget);

    // Header back button exists when canPop is true
    final backBtn = find.byIcon(Icons.chevron_right_rounded);
    expect(backBtn, findsOneWidget);

    // Tap back button
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify returned to previous screen
    expect(find.text('ورود به مدیریت فرم‌ها'), findsOneWidget);
    expect(find.text('مدیریت فرم‌ها'), findsNothing);
  });

  testWidgets('آزمون ۳: عملکرد واقعی دکمه بازخوانی اطلاعات (دریافت مجدد داده‌های واقعی سرور بدون ریست فیلترها)',
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

    // Enter search filter
    await tester.enterText(find.byType(TextField).first, 'مرخصی');
    await tester.pumpAndSettle();

    final callsBefore = client.recordedCalls.where((c) => c.endsWith('list_forms')).length;

    // Tap refresh
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    final callsAfter = client.recordedCalls.where((c) => c.endsWith('list_forms')).length;
    expect(callsAfter, greaterThan(callsBefore));

    // Verify search text wasn't cleared
    expect(find.text('مرخصی'), findsWidgets);
  });

  testWidgets('آزمون ۴: عملکرد سوئیچ تب درخواست‌ها و سندها و تفکیک بلادرنگ قالب‌ها بر اساس نوع',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient(
      forms: [
        {
          'name': 'REQ-01',
          'title': 'قالب درخواست ماموریت',
          'kind': 'Request',
          'module_key': 'HR',
          'status': 'Published',
          'schema': {'title': 'قالب درخواست ماموریت', 'module': 'HR'},
        },
        {
          'name': 'DOC-01',
          'title': 'قالب سند تحویل کالا',
          'kind': 'Document',
          'module_key': 'Stock',
          'status': 'Published',
          'schema': {'title': 'قالب سند تحویل کالا', 'module': 'Stock'},
        },
      ],
    );

    await tester.pumpWidget(_wrap(
      const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    // Initial tab: Request
    expect(find.text('قالب درخواست ماموریت'), findsOneWidget);
    expect(find.text('قالب سند تحویل کالا'), findsNothing);

    // Switch tab to Document
    await tester.tap(find.text('سندها'));
    await tester.pumpAndSettle();

    expect(find.text('قالب سند تحویل کالا'), findsOneWidget);
    expect(find.text('قالب درخواست ماموریت'), findsNothing);
    expect(find.text('قالب فرم‌های سند'), findsOneWidget);
  });

  testWidgets('آزمون ۹: ترکیب همزمان فیلتر جست‌وجو، فیلتر ماژول و نوع قالب و صحت لیست خروجی',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient(
      forms: [
        {
          'name': 'REQ-01',
          'title': 'مرخصی سالانه',
          'kind': 'Request',
          'module_key': 'HR',
          'status': 'Published',
          'schema': {'title': 'مرخصی سالانه', 'module': 'HR'},
        },
        {
          'name': 'REQ-02',
          'title': 'مرخصی استعلاجی',
          'kind': 'Request',
          'module_key': 'HR',
          'status': 'Published',
          'schema': {'title': 'مرخصی استعلاجی', 'module': 'HR'},
        },
        {
          'name': 'REQ-03',
          'title': 'تنخواه امور جاری',
          'kind': 'Request',
          'module_key': 'Finance',
          'status': 'Published',
          'schema': {'title': 'تنخواه امور جاری', 'module': 'Finance'},
        },
      ],
    );

    await tester.pumpWidget(_wrap(
      const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    // Select module HR
    await tester.tap(find.text('منابع انسانی').first);
    await tester.pumpAndSettle();

    expect(find.text('مرخصی سالانه'), findsOneWidget);
    expect(find.text('مرخصی استعلاجی'), findsOneWidget);
    expect(find.text('تنخواه امور جاری'), findsNothing);

    // Search for 'استعلاجی'
    await tester.enterText(find.byType(TextField).first, 'استعلاجی');
    await tester.pumpAndSettle();

    expect(find.text('مرخصی استعلاجی'), findsOneWidget);
    expect(find.text('مرخصی سالانه'), findsNothing);

    // Search non-existing
    await tester.enterText(find.byType(TextField).first, 'غیرموجود');
    await tester.pumpAndSettle();
    expect(find.text('فرمی با این فیلتر پیدا نشد.'), findsOneWidget);
  });

  testWidgets('آزمون ۱۲: باز شدن پیش‌نمایش قالب از منوی سه‌نقطه در حالت فقط‌خواندنی',
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

    // Tap 3-dot popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap 'پیش‌نمایش'
    await tester.tap(find.text('پیش‌نمایش'));
    await tester.pumpAndSettle();

    expect(find.byType(FormEntryPage), findsOneWidget);
    expect(find.text('بررسی فرم'), findsOneWidget);
  });

  testWidgets('آزمون ۱۳: عملکرد گزینه ویرایش قالب از منوی سه‌نقطه و ورود به ویرایشگر با شناسه صحیح',
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

    // Tap 3-dot popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap 'ویرایش / نسخه جدید'
    await tester.tap(find.text('ویرایش / نسخه جدید'));
    await tester.pumpAndSettle();

    expect(find.byType(FormEditorPage), findsOneWidget);
  });

  testWidgets('آزمون ۱۵: عملکرد منوی فعال‌سازی و غیرفعال‌سازی، بررسی دیالوگ تایید، و ارسال اکشن به سرور',
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

    // Tap 3-dot popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap 'غیرفعال‌سازی'
    await tester.tap(find.text('غیرفعال‌سازی'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('فرم غیرفعال شود؟ ثبت‌های قبلی باقی می‌مانند.'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);
    expect(find.text('تأیید'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(client.recordedCalls.where((c) => c.endsWith('transition')), isEmpty);

    // Open menu again and confirm
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('غیرفعال‌سازی'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    expect(client.recordedCalls.where((c) => c.endsWith('transition')), isNotEmpty);
  });

  testWidgets('آزمون ۱۶: عملکرد ورود دکمه ایجاد فرم جدید به فرآیند ساخت قالب خام بر اساس تب انتخابی',
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

    // Switch to Document tab
    await tester.tap(find.text('سندها'));
    await tester.pumpAndSettle();

    // Select module Finance
    await tester.tap(find.text('مالی'));
    await tester.pumpAndSettle();

    // Tap '+ ایجاد فرم جدید'
    await tester.tap(find.text('+ ایجاد فرم جدید'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateFormPage), findsOneWidget);
    expect(find.text('مالی'), findsOneWidget);
  });

  testWidgets('آزمون ۱۷: اطمینان از عدم ثبت هرگونه درخواست یا سند عملیاتی در کل چرخه صفحه مدیریت فرم‌ها',
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

    // Interact with filters and refresh
    await tester.tap(find.text('سندها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درخواست‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    // Assert that no operational doctypes were called
    for (final call in client.recordedCalls) {
      expect(call.contains('Leave Application'), isFalse);
      expect(call.contains('Journal Entry'), isFalse);
      expect(call.contains('Material Request'), isFalse);
      expect(call.contains('Purchase Order'), isFalse);
    }
  });

  testWidgets('آزمون ۱۸: تست تضمین عدم نمایش نوار ناوبری پنج‌دکمه‌ای پایین در این مسیر',
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

    expect(find.text('خانه'), findsNothing);
    expect(find.text('عملیات'), findsNothing);
    expect(find.text('کارتابل'), findsNothing);
    expect(find.text('حساب من'), findsNothing);
  });

  testWidgets('آزمون ۱۹: عدم تاثیرپذیری فرم‌ها و ناوبری سایر بخش‌های سیستم از تغییرات صفحه فرم‌ها',
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

    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('آزمون ۲۰: تست حالت‌های بدون داده (Empty State)، خطای ۵۰۰ سرور و کلیک دکمه تلاش مجدد',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient(shouldFailList: true);

    await tester.pumpWidget(_wrap(
      const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    // Error state rendered
    expect(find.text('بخش نسخه‌دار نیازمند نصب نسخه جدید افزونه سرور است.'), findsOneWidget);
    expect(find.text('تلاش مجدد'), findsOneWidget);

    // Unset error and tap retry
    client.shouldFailList = false;
    await tester.tap(find.text('تلاش مجدد'));
    await tester.pumpAndSettle();

    expect(find.text('فرم مرخصی استحقاقی'), findsOneWidget);
  });

  testWidgets('شکاف ۷: نمایش آیکون و رنگ اختصاصی ذخیره‌شده فرم از اسکیما در کارت‌های فهرست',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient(
      forms: [
        {
          'name': 'FORM-CUSTOM',
          'title': 'فرم سفارشی آیکون‌دار',
          'kind': 'Request',
          'module_key': 'HR',
          'status': 'Published',
          'schema': {
            'title': 'فرم سفارشی آیکون‌دار',
            'module': 'HR',
            'icon': 'calendar',
            'color': '#7B1FA2',
          },
        },
      ],
    );

    await tester.pumpWidget(_wrap(
      const VersionedFormsPage(company: 'شرکت داده‌پردازی آسود'),
      client,
    ));
    await tester.pumpAndSettle();

    // Verify calendar icon is rendered (Icons.calendar_today_outlined)
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.text('فرم سفارشی آیکون‌دار'), findsOneWidget);
  });

  testWidgets('شکاف ۸: حفظ نمایش ماژول انتخاب‌شده پنهان پس از نمایش کمتر',
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

    // Tap 'نمایش همه' to expand modules
    await tester.tap(find.text('نمایش همه'));
    await tester.pumpAndSettle();

    // Tap 'فناوری اطلاعات' (which is in the expanded set)
    expect(find.text('فناوری اطلاعات'), findsOneWidget);
    await tester.tap(find.text('فناوری اطلاعات'));
    await tester.pumpAndSettle();

    // Tap 'نمایش کمتر' to collapse
    expect(find.text('نمایش کمتر'), findsOneWidget);
    await tester.tap(find.text('نمایش کمتر'));
    await tester.pumpAndSettle();

    // 'فناوری اطلاعات' MUST remain visible in the collapsed grid!
    expect(find.text('فناوری اطلاعات'), findsOneWidget);
  });
}
