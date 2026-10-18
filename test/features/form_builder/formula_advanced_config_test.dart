import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/field_sheet/advanced/computed/formula_advanced_config.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
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

  testWidgets('تست ۱۱: افزودن و حذف پرانتز در ماشین‌حساب', (tester) async {
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

    await tester.ensureVisible(find.text('ساخت فرمول'));
    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();

    // Tap (
    await tester.ensureVisible(find.widgetWithText(ActionChip, '('));
    await tester.tap(find.widgetWithText(ActionChip, '('));
    await tester.pumpAndSettle();

    // Tap field
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.tap(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.pumpAndSettle();

    // Tap )
    await tester.ensureVisible(find.widgetWithText(ActionChip, ')'));
    await tester.tap(find.widgetWithText(ActionChip, ')'));
    await tester.pumpAndSettle();

    // Verify chips in formula box
    expect(find.widgetWithText(InputChip, '('), findsOneWidget);
    expect(find.widgetWithText(InputChip, '«تعداد»'), findsOneWidget);
    expect(find.widgetWithText(InputChip, ')'), findsOneWidget);

    // Delete )
    final deleteIcon = find.descendant(
      of: find.widgetWithText(InputChip, ')'),
      matching: find.byType(Icon),
    );
    await tester.ensureVisible(deleteIcon);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, ')'), findsNothing);
  });

  testWidgets('تست ۱۲: استفاده از عدد ثابت در فرمول', (tester) async {
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {'key': 'total', 'label': 'مبلغ نهایی', 'type': 'Formula'},
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ساخت فرمول'));
    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ActionChip, 'عدد ثابت'));
    await tester.tap(find.widgetWithText(ActionChip, 'عدد ثابت'));
    await tester.pumpAndSettle();

    expect(find.text('افزودن عدد ثابت'), findsOneWidget);
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '25');
    await tester.tap(find.text('افزودن'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, '25'), findsOneWidget);
  });

  testWidgets('تست ۱۳: استفاده از تابع شرطی IF با شاخه فعال و غیرفعال', (tester) async {
    // Engine tests for IF with active and inactive branch
    final trueResult = calculateForm(
      const {
        'expression': 'IF(quantity > 2, unit_price, 0)',
        'inputs': ['quantity', 'unit_price'],
      },
      {'quantity': '3', 'unit_price': '500000'},
    );
    expect(trueResult, '500000.00');

    final falseResult = calculateForm(
      const {
        'expression': 'IF(quantity > 2, unit_price, 0)',
        'inputs': ['quantity', 'unit_price'],
      },
      {'quantity': '1', 'unit_price': '500000'},
    );
    expect(falseResult, '0.00');

    // Lazy evaluation: division by zero in inactive branch does not fail
    final lazyResult = calculateForm(
      const {
        'expression': 'IF(quantity > 0, 100 / quantity, 100 / zero)',
        'inputs': ['quantity', 'zero'],
      },
      {'quantity': '5', 'zero': '0'},
    );
    expect(lazyResult, '20.00');

    // UI test: IF button exists in calculator
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {'key': 'total', 'label': 'مبلغ نهایی', 'type': 'Formula'},
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'IF شرطی'), findsOneWidget);
  });

  testWidgets('تست ۱۴: عملکرد توابع MAX، MIN و ROUND در سطح موتور و UI', (tester) async {
    // Engine tests
    expect(
      calculateForm(
        const {'expression': 'ROUND(unit_price / 3, 2)', 'inputs': ['unit_price']},
        {'unit_price': '10'},
      ),
      '3.33',
    );
    expect(
      calculateForm(
        const {'expression': 'MAX(quantity, 5)', 'inputs': ['quantity']},
        {'quantity': '3'},
      ),
      '5.00',
    );
    expect(
      calculateForm(
        const {'expression': 'MIN(quantity, 5)', 'inputs': ['quantity']},
        {'quantity': '3'},
      ),
      '3.00',
    );

    // UI buttons check
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {'key': 'total', 'label': 'مبلغ نهایی', 'type': 'Formula'},
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'ROUND گردکردن'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'MAX بیشترین'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'MIN کمترین'), findsOneWidget);
  });

  testWidgets('تست ۱۵: توابع تو در تو', (tester) async {
    final nested = calculateForm(
      const {
        'expression': 'IF(quantity > 0, ROUND(unit_price / quantity, 2), 0)',
        'inputs': ['quantity', 'unit_price'],
      },
      {'quantity': '3', 'unit_price': '10'},
    );
    expect(nested, '3.33');

    final nestedMaxMin = calculateForm(
      const {
        'expression': 'MAX(quantity, MIN(unit_price, 5))',
        'inputs': ['quantity', 'unit_price'],
      },
      {'quantity': '2', 'unit_price': '10'},
    );
    expect(nestedMaxMin, '5.00');
  });

  testWidgets('تست ۱۶: تجمیع MIN و MAX روی جدول تکرارشونده', (tester) async {
    final rows = [
      {'amount': '10'},
      {'amount': '2.5'},
      {'amount': '8'},
    ];
    final minRes = calculateForm(
      const {'op': 'min', 'table': 'items', 'columns': ['amount']},
      {'items': rows},
    );
    expect(minRes, '2.50');

    final maxRes = calculateForm(
      const {'op': 'max', 'table': 'items', 'columns': ['amount']},
      {'items': rows},
    );
    expect(maxRes, '10.00');

    final emptyRes = calculateForm(
      const {'op': 'min', 'table': 'items', 'columns': ['amount']},
      {'items': <dynamic>[]},
    );
    expect(emptyRes, '0.00');
  });

  testWidgets('تست ۱۷: هشدار هنگام تغییر فیلد محاسباتی مقصد با تغییرات ذخیره‌نشده', (tester) async {
    await tester.pumpWidget(_wrap(
      FormulaAdvancedConfig(
        field: const {
          'key': 'total',
          'label': 'مبلغ نهایی',
          'type': 'Formula',
          'formula': {'op': 'add', 'inputs': ['quantity']},
        },
        schema: _schema,
        fieldOptions: const {'quantity': 'تعداد'},
        onChanged: (_) {},
      ),
      360,
    ));
    await tester.pumpAndSettle();

    // Open calculator and modify draft
    await tester.ensureVisible(find.text('اصلاح فرمول'));
    await tester.tap(find.text('اصلاح فرمول'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ActionChip, '('));
    await tester.tap(find.widgetWithText(ActionChip, '('));
    await tester.pumpAndSettle();

    // Now attempt to switch target field to gross_amount
    final dropdownFinder = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('مبلغ ناخالص').last);
    await tester.pumpAndSettle();

    // Dialog appears!
    expect(find.text('تغییر فیلد محاسباتی مقصد'), findsOneWidget);
    expect(
      find.text('تغییرات ذخیره‌نشده‌ای در فرمول فعلی وجود دارد. آیا می‌خواهید تغییرات را نادیده بگیرید؟'),
      findsOneWidget,
    );

    // Cancel dialog
    final cancelBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('انصراف'),
    );
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    expect(find.text('تغییر فیلد محاسباتی مقصد'), findsNothing);

    // Try again and confirm discard
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('مبلغ ناخالص').last);
    await tester.pumpAndSettle();

    final confirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('نادیده گرفتن و تغییر'),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('مبلغ ناخالص'), findsAtLeastNWidgets(1));
  });
}
