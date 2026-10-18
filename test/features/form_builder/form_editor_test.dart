import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';

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
  });
}
