import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/field_sheet/advanced/computed/formula_advanced_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, double width) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 1000)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

const _schema = <String, dynamic>{
  'title': 'فرم خرید',
  'sections': [
    {
      'fields': [
        {'key': 'quantity', 'label': 'تعداد', 'type': 'Integer'},
        {'key': 'unit_price', 'label': 'قیمت واحد', 'type': 'Money'},
        {
          'key': 'gross_amount',
          'label': 'مبلغ ناخالص',
          'type': 'Formula',
          'formula': {
            'op': 'multiply',
            'inputs': ['quantity', 'unit_price'],
          },
        },
        {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {
            'op': 'chain',
            'ops': ['multiply', 'divide'],
            'inputs': ['quantity', 'unit_price', 'gross_amount'],
          },
        },
      ],
    },
  ],
  'rules': [],
};

void main() {
  testWidgets('تنظیمات محاسباتی در عرض ۳۲۰ و ۳۶۰ بدون سرریز رندر می‌شود',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      final exceptions = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = exceptions.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(_wrap(
        FormulaAdvancedConfig(
          field: const {
            'key': 'total',
            'label': 'مبلغ نهایی',
            'type': 'Formula',
            'formula': {
              'op': 'multiply',
              'inputs': ['quantity', 'unit_price'],
            },
          },
          schema: _schema,
          fieldOptions: const {
            'quantity': 'تعداد',
            'unit_price': 'قیمت واحد',
            'gross_amount': 'مبلغ ناخالص',
          },
          onChanged: (_) {},
        ),
        width,
      ));
      await tester.pumpAndSettle();

      expect(find.text('تنظیمات محاسباتی'), findsOneWidget);
      expect(find.text('فیلدهای ساخته‌شده در فرم نمونه'), findsOneWidget);
      expect(find.text('روش محاسبه'), findsOneWidget);
      expect(find.text('مقادیر آزمایشی فیلدهای فرم'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(exceptions, isEmpty);
    }
  });

  testWidgets('کارت فیلدهای ساخته‌شده باز و بسته می‌شود و زیرعنوان و آیکون دارد',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {'key': 'total', 'label': 'مبلغ نهایی', 'type': 'Formula'},
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد', 'unit_price': 'قیمت واحد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('فیلد موجود · عدد'), findsOneWidget);
    expect(find.text('فیلد موجود · مبلغ'), findsOneWidget);

    // Toggle collapse
    await tester.tap(find.text('فیلدهای ساخته‌شده در فرم نمونه'));
    await tester.pumpAndSettle();
    expect(find.text('فیلد موجود · عدد'), findsNothing);

    // Toggle expand
    await tester.tap(find.text('فیلدهای ساخته‌شده در فرم نمونه'));
    await tester.pumpAndSettle();
    expect(find.text('فیلد موجود · عدد'), findsOneWidget);
  });

  testWidgets('تغییر بین حالت عادی و پیشرفته کنترل‌ها را تغییر می‌دهد',
      (tester) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {
            'op': 'add',
            'inputs': ['quantity', 'unit_price'],
          },
        },
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد', 'unit_price': 'قیمت واحد'},
        onChanged: (f) => saved = f,
      ),
      360,
    ));
    await tester.pumpAndSettle();

    // Default is advanced
    expect(find.text('فرمول ساخته‌شده'), findsOneWidget);
    expect(find.text('تأیید فرمول عادی'), findsNothing);

    // Switch to normal
    await tester.tap(find.text('عادی'));
    await tester.pumpAndSettle();
    expect(find.text('تأیید فرمول عادی'), findsOneWidget);
    expect(find.text('فیلد اول'), findsOneWidget);
    expect(find.text('فیلد دوم'), findsOneWidget);
    expect(find.text('عملگر'), findsOneWidget);

    // Confirm normal formula
    await tester.ensureVisible(find.text('تأیید فرمول عادی'));
    await tester.tap(find.text('تأیید فرمول عادی'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);

    // Switch back to advanced
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    expect(find.text('فرمول ساخته‌شده'), findsOneWidget);
    expect(find.text('تأیید فرمول عادی'), findsNothing);
  });

  testWidgets('فرمولساز پیشرفته توکن‌ها را اضافه می‌کند و فرمول را اعمال یا انصراف می‌دهد',
      (tester) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {'key': 'total', 'label': 'مبلغ نهایی', 'type': 'Formula'},
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد', 'unit_price': 'قیمت واحد'},
        onChanged: (formula) => saved = formula,
      ),
      360,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();
    expect(find.text('ماشین‌حساب فرمول'), findsOneWidget);
    expect(saved, isNull);

    // Cancel draft
    await tester.ensureVisible(find.text('انصراف').last);
    await tester.tap(find.text('انصراف').last);
    await tester.pumpAndSettle();
    expect(find.text('ماشین‌حساب فرمول'), findsNothing);
    expect(saved, isNull);

    // Reopen and build formula
    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.tap(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.tap(find.widgetWithText(ActionChip, 'قیمت واحد'));
    await tester.ensureVisible(find.text('تأیید فرمول'));
    await tester.tap(find.text('تأیید فرمول'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['inputs'], containsAll(['quantity', 'unit_price']));
  });

  testWidgets('اعتبارسنجی ارجاع به خود و فیلد مفقود پیام خطای فارسی نمایش می‌دهد',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {
            'op': 'add',
            'inputs': ['total', 'quantity'],
          },
        },
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ارجاع فیلد به خودش در فرمول مجاز نیست.'), findsOneWidget);

    // Missing field reference
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {
            'op': 'add',
            'inputs': ['deleted_field', 'quantity'],
          },
        },
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('فیلد مرجع «deleted_field» در فرم وجود ندارد.'), findsOneWidget);
  });

  testWidgets('پنل نتایج مقادیر فیلدهای محاسباتی فرم را با فرمت سه‌رقمی نمایش می‌دهد',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {
            'op': 'chain',
            'ops': ['multiply', 'divide'],
            'inputs': ['quantity', 'unit_price', 'gross_amount'],
          },
        },
        schema: _schema,
        fieldOptions: const {
          'quantity': 'تعداد',
          'unit_price': 'قیمت واحد',
          'gross_amount': 'مبلغ ناخالص',
        },
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    // In the results panel, gross_amount (3 * 500,000 = 1,500,000) is shown
    expect(find.text('1,500,000'), findsOneWidget);
    // Formula text has Persian brackets «»
    expect(find.text('«تعداد» × «قیمت واحد» ÷ «مبلغ ناخالص»'), findsOneWidget);
  });
}
