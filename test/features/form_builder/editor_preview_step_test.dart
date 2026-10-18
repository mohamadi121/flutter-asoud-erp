import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_preview_step.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/print_preview.dart';

class _FakeClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager'],
        company: 'شرکت نمونه آسود',
      );
}

Widget _wrap(Widget child, [double width = 360]) => MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = FormRepository(_FakeClient(), 'شرکت نمونه آسود');

  final testSchema = <String, dynamic>{
    'title': 'درخواست خرید کالا',
    'module': 'Purchase',
    'sections': [
      {
        'id': 'sec_main',
        'title': 'اطلاعات اصلی',
        'fields': [
          {
            'key': 'title',
            'label': 'موضوع درخواست',
            'type': 'Text',
            'required': true,
          },
        ],
      },
      {
        'id': 'sec_items',
        'title': 'اطلاعات اقلام',
        'fields': [
          {
            'key': 'items',
            'label': 'اقلام درخواست خرید',
            'type': 'Table',
            'min_rows': 1,
            'columns': [
              {
                'key': 'name',
                'label': 'نام کالا',
                'type': 'Text',
              },
              {
                'key': 'qty',
                'label': 'تعداد',
                'type': 'Integer',
              },
              {
                'key': 'rate',
                'label': 'قیمت واحد',
                'type': 'Money',
              },
              {
                'key': 'amount',
                'label': 'مبلغ ردیف',
                'type': 'Formula',
                'formula': {
                  'op': 'multiply',
                  'inputs': ['qty', 'rate'],
                },
              },
            ],
          },
        ],
      },
    ],
  };

  testWidgets('کارت پیش‌نمایش موبایل نشان، سربرگ و دکمه‌های پایین را رندر می‌کند',
      (tester) async {
    String? notice;
    String? error;

    await tester.pumpWidget(_wrap(
      EditorPreviewStep(
        schema: testSchema,
        record: const {'name': 'FORM-001', 'title': 'درخواست خرید کالا'},
        options: const {},
        preview: const {
          'title': 'خرید لپ‌تاپ',
          'items': [
            {'name': 'لپ‌تاپ', 'qty': '1', 'rate': '50000000', 'amount': '50000000'}
          ],
        },
        previewKey: GlobalKey<FormState>(),
        repository: repo,
        busy: false,
        change: (_) {},
        save: ([_]) async {},
        onPreviewChanged: (_) {},
        onError: (e) => error = e,
        onNotice: (n) => notice = n,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify header card
    expect(find.text('پیش‌نمایش'), findsOneWidget);
    expect(find.text('درخواست خرید کالا'), findsWidgets);
    expect(find.text('نمای آزمایشی Purchase'), findsOneWidget);

    // Verify section banners
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
    expect(find.text('اطلاعات اقلام'), findsOneWidget);

    // Verify action buttons
    expect(find.text('نمای چاپ'), findsOneWidget);
    expect(find.text('آزمایش ثبت'), findsOneWidget);

    // Tap آزمایش ثبت
    await tester.ensureVisible(find.text('آزمایش ثبت'));
    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pumpAndSettle();

    expect(error, isNull);
    expect(notice, contains('ساختار و مقادیر فرم با موفقیت در حالت آزمایشی'));
  });

  testWidgets('آزمایش ثبت در صورت وجود خطا یا عدم رعایت حداقل ردیف خطا می‌دهد',
      (tester) async {
    String? notice;
    String? error;

    await tester.pumpWidget(_wrap(
      EditorPreviewStep(
        schema: testSchema,
        record: const {'name': 'FORM-001', 'title': 'درخواست خرید کالا'},
        options: const {},
        preview: const {
          // missing required title and items is empty while min_rows=1
          'items': [],
        },
        previewKey: GlobalKey<FormState>(),
        repository: repo,
        busy: false,
        change: (_) {},
        save: ([_]) async {},
        onPreviewChanged: (_) {},
        onError: (e) => error = e,
        onNotice: (n) => notice = n,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('آزمایش ثبت'));
    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pumpAndSettle();

    expect(notice, isNull);
    expect(error, isNotNull);
    expect(error, contains('حداقل نیازمند ۱ ردیف است'));
  });

  testWidgets('دکمه نمای چاپ صفحه FormPrintPreviewPage را باز می‌کند',
      (tester) async {
    await tester.pumpWidget(_wrap(
      EditorPreviewStep(
        schema: testSchema,
        record: const {'name': 'FORM-001', 'title': 'درخواست خرید کالا'},
        options: const {},
        preview: const {'title': 'خرید اقلام'},
        previewKey: GlobalKey<FormState>(),
        repository: repo,
        busy: false,
        change: (_) {},
        save: ([_]) async {},
        onPreviewChanged: (_) {},
        onError: (_) {},
        onNotice: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('نمای چاپ'));
    await tester.tap(find.text('نمای چاپ'));
    await tester.pumpAndSettle();

    expect(find.byType(FormPrintPreviewPage), findsOneWidget);
    expect(find.text('پیش‌نمایش چاپ فرم'), findsOneWidget);
  });

  testWidgets('کارت پیش‌نمایش در عرض‌های ۳۲۰ و ۳۶۰ بدون سرریز رندر می‌شود',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      await tester.pumpWidget(_wrap(
        EditorPreviewStep(
          schema: testSchema,
          record: const {'name': 'FORM-001', 'title': 'درخواست خرید کالا'},
          options: const {},
          preview: const {
            'title': 'عنوان طولانی تست عرض بدون سرریز',
            'items': [
              {'name': 'کالا ۱', 'qty': '2', 'rate': '1000', 'amount': '2000'}
            ],
          },
          previewKey: GlobalKey<FormState>(),
          repository: repo,
          busy: false,
          change: (_) {},
          save: ([_]) async {},
          onPreviewChanged: (_) {},
          onError: (_) {},
          onNotice: (_) {},
        ),
        width,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });
}
