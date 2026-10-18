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

  testWidgets('شکاف ۱: روش الگوی آماده نیازمند انتخاب الگوست و خطای فارسی نمایش می‌دهد',
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

    // Select template mode
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();

    // Enter title so title validation passes
    await tester.enterText(find.byType(TextField).first, 'فرم تستی بدون الگو');
    await tester.pumpAndSettle();

    // Tap submit without choosing preset
    await tester.tap(find.text('تأیید و ادامه'));
    await tester.pumpAndSettle();

    // Verify Persian SnackBar error is shown
    expect(find.text('لطفاً یک الگوی آماده انتخاب کنید.'), findsOneWidget);
    // Verify FormEditorPage was NOT opened
    expect(find.byType(FormEditorPage), findsNothing);
  });

  testWidgets('شکاف ۲ و ۳: انتقال آیکون، رنگ و توضیحات اولیه از الگو و نمایش آیکون الگو در کادر فشرده',
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

    // Switch to template mode
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();

    // Before selection: compact picker shows copy icon
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    // Open sheet and pick 'درخواست مرخصی'
    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('درخواست مرخصی'));
    await tester.pumpAndSettle();

    // Title populated
    expect(find.text('کپی درخواست مرخصی'), findsOneWidget);

    // Description populated
    expect(find.text('قالب آماده برای ثبت انواع مرخصی استحقاقی، استعلاجی و ساعتی'), findsOneWidget);

    // Compact picker now shows the template icon (calendar)
    expect(find.byIcon(Icons.calendar_today_outlined), findsWidgets);
  });

  testWidgets('شکاف ۴: عدم فال‌بک به سایر ماژول‌ها و نمایش پیام «الگویی برای این ماژول یافت نشد»',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();
    final repo = FormRepository(client, 'شرکت داده‌پردازی آسود');

    // HR has no presets for Document
    await tester.pumpWidget(_wrap(
      CreateFormPage(
        repository: repo,
        selectedModule: 'HR',
        initialKind: 'Document',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    // Select template mode
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();

    // Open template picker sheet
    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();

    // Must show exact Persian message for no module presets and NOT fallback to Purchase/Finance presets
    expect(find.text('الگویی برای این ماژول یافت نشد.'), findsOneWidget);
    expect(find.text('درخواست کالا'), findsNothing);
    expect(find.text('سند حسابداری'), findsNothing);
  });

  testWidgets('شکاف ۵: نمایش خطای عنوان زیر فیلد به صورت errorText و حذف آن هنگام تایپ',
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

    // Submit with empty title
    await tester.tap(find.text('تأیید و ادامه'));
    await tester.pumpAndSettle();

    // Error text is rendered under the TextField
    expect(find.text('لطفاً عنوان قالب فرم را وارد کنید.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Enter text in title field
    await tester.enterText(find.byType(TextField).first, 'عنوان معتبر');
    await tester.pumpAndSettle();

    // Error text is cleared
    expect(find.text('لطفاً عنوان قالب فرم را وارد کنید.'), findsNothing);
  });

  testWidgets('شکاف ۶: ورود مستقیم با ماژول خالی شیت انتخاب ماژول را باز می‌کند',
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
        selectedModule: '',
        initialKind: 'Request',
      ),
      client,
    ));
    await tester.pumpAndSettle();

    // pickModuleModal opened automatically
    expect(find.text('انتخاب ماژول'), findsOneWidget);
    expect(find.text('برای ایجاد فرم جدید، ابتدا ماژول مربوطه را مشخص کنید.'), findsOneWidget);

    // Pick 'فناوری اطلاعات'
    await tester.tap(find.text('فناوری اطلاعات'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // Module card updated
    expect(find.text('فناوری اطلاعات'), findsOneWidget);
  });

  testWidgets('شکاف ۹: رفتار دکمه بازگشت و PopScope در صورت وجود تغییرات ذخیره‌نشده',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeManagerClient();
    final repo = FormRepository(client, 'شرکت داده‌پردازی آسود');

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
                      builder: (_) => CreateFormPage(
                        repository: repo,
                        selectedModule: 'HR',
                        initialKind: 'Request',
                      ),
                    ),
                  ),
                  child: const Text('ایجاد فرم'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ایجاد فرم'));
    await tester.pumpAndSettle();
    expect(find.text('ایجاد فرم جدید'), findsOneWidget);

    // Enter unsaved changes in title
    await tester.enterText(find.byType(TextField).first, 'پیش‌نویس ذخیره‌نشده');
    await tester.pumpAndSettle();

    // Trigger back
    final backBtn = find.byIcon(Icons.chevron_right_rounded);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('تغییرات ذخیره نشده از دست خواهند رفت. آیا خارج می‌شوید؟'), findsOneWidget);

    // Tap cancel ('انصراف') -> stays on CreateFormPage
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(find.text('ایجاد فرم جدید'), findsOneWidget);

    // Trigger back again and confirm ('تأیید')
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    // Pops back to root
    expect(find.text('ایجاد فرم'), findsOneWidget);
    expect(find.text('ایجاد فرم جدید'), findsNothing);
  });

  testWidgets('آزمون ۲۱: تغییر نوع قالب (درخواست/سند) الگوی انتخاب‌شده ناسازگار را ریست می‌کند',
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

    // Select template mode and pick 'درخواست مرخصی'
    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درخواست مرخصی'));
    await tester.pumpAndSettle();

    expect(find.text('کپی درخواست مرخصی'), findsOneWidget);

    // Switch kind to 'سند'
    await tester.tap(find.text('سند'));
    await tester.pumpAndSettle();

    // Compact picker is reset to prompt
    expect(find.text('برای انتخاب الگو لمس کنید...'), findsOneWidget);
  });

  testWidgets('جستجوی الگو در شیت با عبارت ناموجود متن «الگویی با این عنوان یافت نشد.» را نمایش می‌دهد',
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

    await tester.tap(find.text('استفاده از الگوی آماده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برای انتخاب الگو لمس کنید...'));
    await tester.pumpAndSettle();

    // Enter search text that matches nothing
    await tester.enterText(find.byType(TextField).last, 'الگوی_غیرواقعی_۹۹۹');
    await tester.pumpAndSettle();

    expect(find.text('الگویی با این عنوان یافت نشد.'), findsOneWidget);

    // Close button dismisses sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب الگوی آماده'), findsNothing);
  });
}
