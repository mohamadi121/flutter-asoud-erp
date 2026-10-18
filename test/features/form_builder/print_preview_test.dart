import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
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
          child: child,
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
          {
            'key': 'date',
            'label': 'تاریخ درخواست',
            'type': 'Date',
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

  final testValues = <String, dynamic>{
    'title': 'خرید ملزومات اداری دفتر مرکزی',
    'date': '2026-10-18',
    'items': [
      {
        'name': 'کاغذ A4 کپی‌مکس',
        'qty': '5',
        'rate': '180000',
        'amount': '900000',
      },
      {
        'name': 'پوشه دکمه‌دار',
        'qty': '20',
        'rate': '15000',
        'amount': '300000',
      },
    ],
  };

  testWidgets('نمای چاپ سربرگ، مشخصات، جدول و امضاها را نمایش می‌دهد',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FormPrintPreviewPage(
        schema: testSchema,
        values: testValues,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify company & header
    expect(find.text('پیش‌نمایش چاپ فرم'), findsOneWidget);
    expect(find.text('شرکت نمونه آسود'), findsOneWidget);
    expect(find.text('درخواست خرید کالا'), findsOneWidget);
    expect(find.text('نسخه آزمایشی / پیش‌نویس'), findsOneWidget);

    // Verify metadata
    expect(find.text('شماره: آزمایشی'), findsOneWidget);
    expect(find.text('واحد سازمانی: Purchase'), findsOneWidget);

    // Verify sections and fields
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
    expect(find.text('موضوع درخواست: '), findsOneWidget);
    expect(find.text('خرید ملزومات اداری دفتر مرکزی'), findsOneWidget);

    // Verify repeating table
    expect(find.text('اقلام درخواست خرید:'), findsOneWidget);
    expect(find.text('کاغذ A4 کپی‌مکس'), findsOneWidget);
    expect(find.text('پوشه دکمه‌دار'), findsOneWidget);
    expect(find.text('۹۰۰٬۰۰۰ تومان'), findsOneWidget);
    expect(find.text('۳۰۰٬۰۰۰ تومان'), findsOneWidget);

    // Grand total: 900,000 + 300,000 = 1,200,000
    expect(find.text('۱٬۲۰۰٬۰۰۰ تومان'), findsOneWidget);

    // Signature boxes
    expect(find.text('تأییدیه‌ها و امضاها'), findsOneWidget);
    expect(find.text('متقاضی / درخواست‌کننده'), findsOneWidget);
    expect(find.text('مدیر واحد مربوطه'), findsOneWidget);
    expect(find.text('امور مالی و اداری'), findsOneWidget);
  });

  testWidgets('تغییر جهت A4 بین عمودی و افقی کار می‌کند', (tester) async {
    await tester.pumpWidget(_wrap(
      FormPrintPreviewPage(
        schema: testSchema,
        values: testValues,
        repository: repo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('عمودی'), findsOneWidget);
    expect(find.text('افقی'), findsOneWidget);

    // Tap Landscape
    await tester.tap(find.text('افقی'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Tap Portrait back
    await tester.tap(find.text('عمودی'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('نمای چاپ در عرض‌های ۳۲۰ و ۳۶۰ بدون خطا رندر می‌شود',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      await tester.pumpWidget(_wrap(
        FormPrintPreviewPage(
          schema: testSchema,
          values: testValues,
          repository: repo,
        ),
        width,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('پیش‌نمایش چاپ فرم'), findsOneWidget);
    }
  });
}
