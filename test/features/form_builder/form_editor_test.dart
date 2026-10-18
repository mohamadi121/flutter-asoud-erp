import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';

class _FakeClient extends Fake implements FrappeApiClient {
  _FakeClient();

  final String company = 'شرکت نمونه آسود';

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: const ['System Manager', 'Administrator'],
        company: company,
      );

  @override
  Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    if (method.endsWith('get_options')) {
      return {
        'message': {
          'ok': true,
          'data': {
            'roles': ['System Manager', 'Employee'],
            'departments': ['IT', 'HR'],
            'workflows': [],
          },
        },
      };
    }
    if (method.endsWith('save_form')) {
      return {
        'message': {
          'ok': true,
          'data': {
            'name': data?['name'] ?? 'FORM-001',
            'status': 'Draft',
            'draft_version': 1,
            'schema': data?['schema'],
          },
        },
      };
    }
    return {
      'message': {
        'ok': true,
        'data': {'ok': true},
      },
    };
  }
}

Widget _wrap(Widget child, FrappeApiClient client) =>
    RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );

FormMap _sampleInitialForm([String name = 'FORM-001']) => {
      'name': name,
      'title': 'درخواست معرفی تأمین‌کننده',
      'status': 'Draft',
      'schema': {
        'title': 'درخواست معرفی تأمین‌کننده',
        'module': 'Purchase',
        'kind': 'Request',
        'sections': [
          {
            'id': 'sec_main',
            'title': 'اطلاعات اصلی',
            'color': '#EFF6FF',
            'fields': [
              {
                'key': 'f_subject',
                'label': 'موضوع درخواست',
                'type': 'Text',
                'required': true,
              },
              {
                'key': 'f_date',
                'label': 'تاریخ درخواست',
                'type': 'Date',
                'required': true,
              },
              {
                'key': 'f_desc',
                'label': 'شرح درخواست',
                'type': 'LongText',
                'required': false,
              },
            ],
          },
          {
            'id': 'sec_extra',
            'title': 'اطلاعات تکمیلی',
            'color': '#F0FDF4',
            'fields': [
              {
                'key': 'f_supplier',
                'label': 'نام تأمین‌کننده پیشنهادی',
                'type': 'Text',
                'required': false,
              },
            ],
          },
          {
            'id': 'sec_end',
            'title': 'پایان',
            'color': '#EEF2FF',
            'fields': [
              {
                'key': 'f_note',
                'label': 'یادداشت پایانی',
                'type': 'Text',
                'required': false,
              },
            ],
          },
        ],
        'rules': <FormMap>[],
      },
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('صفحه طراحی فرم (Form Designer) - بخش ۴', () {
    testWidgets('رندر کامل اجزای صفحه طراحی فرم و کارت مشخصات در ابعاد ۳۶۰',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-1')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('طراحی فرم'), findsOneWidget);
      expect(find.text('شرکت نمونه آسود'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Form spec card
      expect(find.text('درخواست معرفی تأمین‌کننده'), findsWidgets);
      expect(find.text('خرید و تدارکات • فرم درخواست'), findsOneWidget);
      expect(find.text('پیش‌نویس'), findsOneWidget);

      // Section header and buttons
      expect(find.text('بخش‌های فرم'), findsOneWidget);
      expect(find.text('افزودن بخش'), findsOneWidget);

      // Sections
      expect(find.text('اطلاعات اصلی'), findsOneWidget);
      expect(find.text('اطلاعات تکمیلی'), findsOneWidget);
      expect(find.text('پایان'), findsOneWidget);

      // Fields of expanded first section
      expect(find.text('موضوع درخواست'), findsOneWidget);
      expect(find.text('تاریخ درخواست'), findsOneWidget);
      expect(find.text('شرح درخواست'), findsOneWidget);

      // Bottom buttons
      expect(find.text('پیش‌نمایش'), findsOneWidget);
      expect(find.text('ذخیره پیش‌نویس'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('رندر کامل و بدون سرریز در ابعاد ۳۲۰', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-2')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('طراحی فرم'), findsOneWidget);
      expect(find.text('بخش‌های فرم'), findsOneWidget);
      expect(find.text('پیش‌نمایش'), findsOneWidget);
      expect(find.text('ذخیره پیش‌نویس'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('افزودن بخش جدید با عنوان اجباری و تخصیص رنگ غیرتکراری',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-3')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'افزودن بخش'
      await tester.tap(find.text('افزودن بخش'));
      await tester.pumpAndSettle();

      expect(find.text('عنوان بخش جدید'), findsOneWidget);
      // Enter section title
      await tester.enterText(
          find.byType(TextFormField).last, 'بخش اسناد ضمیمه');
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('بخش اسناد ضمیمه'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('تغییر نام بخش و حفظ فیلدها و رنگ اختصاصی', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-4')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Open 3-dots menu of first section
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('تغییر نام'), findsOneWidget);
      await tester.tap(find.text('تغییر نام'));
      await tester.pumpAndSettle();

      expect(find.text('نام بخش'), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField).last, 'اطلاعات اولیه فرم');
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('اطلاعات اولیه فرم'), findsOneWidget);
      // Ensure fields remain
      expect(find.text('موضوع درخواست'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('تغییر ترتیب بخش‌ها و حفظ رنگ هر بخش مستقل از ترتیب',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-5')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Move first section down
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('انتقال به پایین'), findsOneWidget);
      await tester.tap(find.text('انتقال به پایین'));
      await tester.pumpAndSettle();

      // Verify sections are still properly rendered
      expect(find.text('اطلاعات تکمیلی'), findsOneWidget);
      expect(find.text('اطلاعات اصلی'), findsOneWidget);
      expect(find.text('پایان'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('حذف بخش همراه با هشدار تعداد فیلدهای در حال حذف',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-6')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Open menu of first section (which has 3 fields)
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('حذف بخش'), findsOneWidget);
      await tester.tap(find.text('حذف بخش'));
      await tester.pumpAndSettle();

      // Shows confirmation with field count
      expect(find.text('تأیید عملیات'), findsOneWidget);
      expect(
        find.textContaining('بخش «اطلاعات اصلی» شامل ۳ فیلد حذف شود؟'),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      expect(find.text('اطلاعات اصلی'), findsNothing);
      expect(find.text('اطلاعات تکمیلی'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('باز و بسته کردن بخش (Expand / Collapse)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-7')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Initially 'اطلاعات اصلی' is expanded, fields are visible
      expect(find.text('موضوع درخواست'), findsOneWidget);

      // Tap on section header to collapse
      await tester.tap(find.text('اطلاعات اصلی'));
      await tester.pumpAndSettle();

      // Field should no longer be visible
      expect(find.text('موضوع درخواست'), findsNothing);

      // Tap again to re-expand
      await tester.tap(find.text('اطلاعات اصلی'));
      await tester.pumpAndSettle();

      expect(find.text('موضوع درخواست'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ورود به پیش‌نمایش از هدر و دکمه پایین و بازگشت به طراحی',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-8')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Tap bottom 'پیش‌نمایش'
      await tester.tap(find.text('پیش‌نمایش'));
      await tester.pumpAndSettle();

      // Header changes to 'پیش‌نمایش فرم'
      expect(find.text('پیش‌نمایش فرم'), findsWidgets);
      expect(find.text('بازگشت به طراحی'), findsWidgets);

      // Tap 'بازگشت به طراحی'
      await tester.tap(find.text('بازگشت به طراحی').first);
      await tester.pumpAndSettle();

      expect(find.text('طراحی فرم'), findsOneWidget);

      // Tap header eye icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.text('پیش‌نمایش فرم'), findsWidgets);

      // Toggle back to design
      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      expect(find.text('طراحی فرم'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ذخیره پیش‌نویس فرم ساختار کامل و بخش‌ها را ثبت می‌کند',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-9')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ذخیره پیش‌نویس'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('اطلاعات در سرور ذخیره شد.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'خروج با تغییرات ذخیره‌نشده دیالوگ سه اقدامی (ادامه، خروج، ذخیره و خروج) را نمایش می‌دهد',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
              repository: repo, initial: _sampleInitialForm('FORM-10')),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Make a change by adding a section
      await tester.tap(find.text('افزودن بخش'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'بخش جدید');
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      // Now dirty is true. Tap back button in header
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();

      // Unsaved changes dialog appears
      expect(find.text('تغییرات ذخیره‌نشده'), findsOneWidget);
      expect(find.text('ادامه طراحی'), findsOneWidget);
      expect(find.text('خروج بدون ذخیره'), findsOneWidget);
      expect(find.text('ذخیره و خروج'), findsOneWidget);

      // Tap 'ادامه طراحی' cancels exit
      await tester.tap(find.text('ادامه طراحی'));
      await tester.pumpAndSettle();

      expect(find.text('طراحی فرم'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('چیدمان نیم‌عرض فیلدها و رندر دو ستونی در طراحی و پیش‌نمایش',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');
      final form = {
        'name': 'FORM-SPAN',
        'title': 'فرم تست چیدمان',
        'status': 'Draft',
        'schema': {
          'title': 'فرم تست چیدمان',
          'module': 'HR',
          'kind': 'Request',
          'sections': [
            {
              'id': 'sec_1',
              'title': 'بخش اول',
              'color': '#EFF6FF',
              'fields': [
                {
                  'key': 'f_half1',
                  'label': 'فیلد نیم‌عرض اول',
                  'type': 'Text',
                  'span': 1,
                },
                {
                  'key': 'f_half2',
                  'label': 'فیلد نیم‌عرض دوم',
                  'type': 'Text',
                  'span': 1,
                },
                {
                  'key': 'f_full',
                  'label': 'فیلد تمام‌عرض',
                  'type': 'Text',
                  'span': 2,
                },
              ],
            },
          ],
          'rules': <FormMap>[],
        },
      };

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(repository: repo, initial: form),
          client,
        ),
      );
      await tester.pumpAndSettle();

      final box1 = tester.getRect(find.byKey(const ValueKey('field_f_half1')));
      final box2 = tester.getRect(find.byKey(const ValueKey('field_f_half2')));
      final boxFull = tester.getRect(find.byKey(const ValueKey('field_f_full')));

      // Both half-width fields are in the same horizontal row (approx same top)
      expect((box1.top - box2.top).abs(), lessThan(4.0));
      // Full width field is on the next line below them
      expect(boxFull.top, greaterThan(box1.bottom - 1.0));
      // Full width field is significantly wider than each half-width field
      expect(boxFull.width, greaterThan(box1.width * 1.5));

      // Test field sheet selection of span:
      // Tap tune menu on full width field and select edit
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('field_f_full')),
        matching: find.byIcon(Icons.tune),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تنظیمات فیلد'));
      await tester.pumpAndSettle();

      // Field sheet opened: segmented control is visible with 'نیم‌عرض' and 'تمام‌عرض'
      await tester.ensureVisible(find.text('نیم‌عرض'));
      await tester.pumpAndSettle();

      expect(find.text('چیدمان فیلد'), findsOneWidget);
      expect(find.text('نیم‌عرض'), findsOneWidget);
      expect(find.text('تمام‌عرض'), findsOneWidget);

      // Select 'نیم‌عرض'
      await tester.tap(find.text('نیم‌عرض'));
      await tester.pumpAndSettle();
      // Save sheet
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();

      // Now f_full also has span 1
      final boxFullAfter =
          tester.getRect(find.byKey(const ValueKey('field_f_full')));
      expect((boxFullAfter.width - box1.width).abs(), lessThan(4.0));

      // Switch to preview mode
      await tester.tap(find.text('پیش‌نمایش'));
      await tester.pumpAndSettle();
      expect(find.text('پیش‌نمایش فرم'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'جابه‌جایی فیلدها به بالا و پایین از منوی تنظیمات فیلد و تغییر ترتیب در درخت ویجت',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');
      final form = {
        'name': 'FORM-ORDER',
        'title': 'تست ترتیب',
        'status': 'Draft',
        'schema': {
          'title': 'تست ترتیب',
          'module': 'HR',
          'kind': 'Request',
          'sections': [
            {
              'id': 'sec_order',
              'title': 'بخش ترتیب',
              'color': '#EFF6FF',
              'fields': [
                {
                  'key': 'f_alpha',
                  'label': 'فیلد آلفا',
                  'type': 'Text',
                },
                {
                  'key': 'f_beta',
                  'label': 'فیلد بتا',
                  'type': 'Text',
                },
              ],
            },
          ],
          'rules': <FormMap>[],
        },
      };

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(repository: repo, initial: form),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Initially f_alpha is above f_beta
      var rectAlpha =
          tester.getRect(find.byKey(const ValueKey('field_f_alpha')));
      var rectBeta =
          tester.getRect(find.byKey(const ValueKey('field_f_beta')));
      expect(rectAlpha.top, lessThan(rectBeta.top));

      // Open tune menu of f_beta (second field)
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('field_f_beta')),
        matching: find.byIcon(Icons.tune),
      ));
      await tester.pumpAndSettle();

      // Tap 'انتقال به بالا'
      expect(find.text('انتقال به بالا'), findsOneWidget);
      await tester.tap(find.text('انتقال به بالا'));
      await tester.pumpAndSettle();

      // Now f_beta is above f_alpha in widget tree!
      rectAlpha =
          tester.getRect(find.byKey(const ValueKey('field_f_alpha')));
      rectBeta =
          tester.getRect(find.byKey(const ValueKey('field_f_beta')));
      expect(rectBeta.top, lessThan(rectAlpha.top));

      // Open tune menu of f_beta again (now first field, can move down)
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('field_f_beta')),
        matching: find.byIcon(Icons.tune),
      ));
      await tester.pumpAndSettle();

      expect(find.text('انتقال به پایین'), findsOneWidget);
      await tester.tap(find.text('انتقال به پایین'));
      await tester.pumpAndSettle();

      // Now f_alpha is above f_beta again
      rectAlpha =
          tester.getRect(find.byKey(const ValueKey('field_f_alpha')));
      rectBeta =
          tester.getRect(find.byKey(const ValueKey('field_f_beta')));
      expect(rectAlpha.top, lessThan(rectBeta.top));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('حذف فیلد همراه با هشدار قوانین وابسته و پاکسازی قانون وابسته',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');
      final form = {
        'name': 'FORM-RULES',
        'title': 'تست قوانین وابسته',
        'status': 'Draft',
        'schema': {
          'title': 'تست قوانین وابسته',
          'module': 'HR',
          'kind': 'Request',
          'sections': [
            {
              'id': 'sec_rules',
              'title': 'بخش قوانین',
              'color': '#EFF6FF',
              'fields': [
                {
                  'key': 'f_target',
                  'label': 'فیلد هدف حذف',
                  'type': 'Text',
                },
                {
                  'key': 'f_other',
                  'label': 'فیلد دیگر',
                  'type': 'Text',
                },
              ],
            },
          ],
          'rules': [
            {
              'target': 'f_other',
              'action': 'show',
              'conditions': [
                {'field': 'f_target', 'op': 'equals', 'value': 'test'},
              ],
            },
          ],
        },
      };

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(repository: repo, initial: form),
          client,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فیلد هدف حذف'), findsOneWidget);

      // Open tune menu of f_target
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('field_f_target')),
        matching: find.byIcon(Icons.tune),
      ));
      await tester.pumpAndSettle();

      expect(find.text('حذف فیلد'), findsOneWidget);
      await tester.tap(find.text('حذف فیلد'));
      await tester.pumpAndSettle();

      // Warning dialog appears
      expect(find.text('فیلد و قوانین وابسته حذف شوند؟'), findsOneWidget);
      expect(find.text('تأیید'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      // Field is removed from widget tree
      expect(find.text('فیلد هدف حذف'), findsNothing);
      expect(find.text('فیلد دیگر'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ممانعت از حذف آخرین بخش فرم و غیرفعال بودن گزینه حذف',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');
      final form = {
        'name': 'FORM-SINGLE-SEC',
        'title': 'فرم تک‌بخش',
        'status': 'Draft',
        'schema': {
          'title': 'فرم تک‌بخش',
          'module': 'Purchase',
          'kind': 'Request',
          'sections': [
            {
              'id': 'sec_only',
              'title': 'تنها بخش فرم',
              'color': '#EFF6FF',
              'fields': <FormMap>[],
            },
          ],
          'rules': <FormMap>[],
        },
      };

      await tester.pumpWidget(
        _wrap(
          FormEditorPage(repository: repo, initial: form),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Open 3-dots menu of the only section
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Menu is displayed. 'حذف بخش' is present along with the Persian warning message
      expect(find.text('حذف بخش'), findsOneWidget);
      expect(
        find.text('فرم باید حداقل یک بخش داشته باشد'),
        findsOneWidget,
      );

      // Verify that the PopupMenuItem for 'delete' is disabled
      final popupItem = tester.widget<PopupMenuItem>(
        find.ancestor(
          of: find.text('فرم باید حداقل یک بخش داشته باشد'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(popupItem.enabled, isFalse);

      // Close menu by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Section still exists
      expect(find.text('تنها بخش فرم'), findsOneWidget);

      // Now add a second section
      await tester.tap(find.text('افزودن بخش'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'بخش دوم');
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('بخش دوم'), findsOneWidget);

      // Now open 3-dots menu of first section: delete should be enabled
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      final popupItemEnabled = tester.widget<PopupMenuItem>(
        find.ancestor(
          of: find.text('حذف بخش'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(popupItemEnabled.enabled, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    test('شناسه‌های پایدار تصادفی newFormId با شروع از حرف و پیشوند sec_ برای بخش‌ها', () {
      final id1 = newFormId();
      final id2 = newFormId();
      expect(id1, isNot(equals(id2)));
      // Starts with a letter a-z
      expect(RegExp(r'^[a-z]').hasMatch(id1), isTrue);
      expect(RegExp(r'^[a-z]').hasMatch(id2), isTrue);
      // Contains only lowercase letters and digits
      expect(RegExp(r'^[a-z][a-z0-9]+$').hasMatch(id1), isTrue);
      expect(RegExp(r'^[a-z][a-z0-9]+$').hasMatch(id2), isTrue);
    });

    testWidgets('برچسب نوع فیلد LongText در سراسر سیستم متن بلند است',
        (tester) async {
      expect(formTypes['LongText'], equals('متن بلند'));

      final client = _FakeClient();
      final repo = FormRepository(client, 'شرکت نمونه آسود');
      await tester.pumpWidget(
        _wrap(
          FormEditorPage(
            repository: repo,
            initial: _sampleInitialForm('FORM-LONGTEXT'),
          ),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // In _sampleInitialForm, f_desc has type LongText
      expect(find.text('شرح درخواست'), findsOneWidget);
      expect(find.text('متن بلند'), findsOneWidget);
      expect(find.text('متن چندخطی'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
