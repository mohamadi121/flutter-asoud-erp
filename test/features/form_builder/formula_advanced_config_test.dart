import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/field_sheet/advanced/computed/formula_advanced_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, double width) => MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
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
            'type': 'Formula'
          },
          schema: _schema,
          fieldOptions: const {'quantity': 'تعداد', 'unit_price': 'قیمت واحد'},
          onChanged: (_) {},
        ),
        width,
      ));
      await tester.pumpAndSettle();

      expect(find.text('تنظیمات محاسباتی'), findsOneWidget);
      expect(find.text('ساخت فرمول'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(exceptions, isEmpty);
    }
  });

  testWidgets('تأیید فرمول پیش‌نویس را اعمال و انصراف آن را کنار می‌گذارد',
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

    await tester.ensureVisible(find.text('انصراف').last);
    await tester.tap(find.text('انصراف').last);
    await tester.pumpAndSettle();
    expect(find.text('ماشین‌حساب فرمول'), findsNothing);
    expect(saved, isNull);

    await tester.tap(find.text('ساخت فرمول'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.tap(find.widgetWithText(ActionChip, 'تعداد'));
    await tester.tap(find.widgetWithText(ActionChip, 'قیمت واحد'));
    await tester.ensureVisible(find.text('تأیید فرمول'));
    await tester.tap(find.text('تأیید فرمول'));
    await tester.pumpAndSettle();

    expect(
        saved,
        equals({
          'op': 'add',
          'inputs': ['quantity', 'unit_price'],
          'columns': [],
          'precision': 2
        }));
    expect(find.text('نتیجه نمونه: 2.00'), findsWidgets);
  });
}
