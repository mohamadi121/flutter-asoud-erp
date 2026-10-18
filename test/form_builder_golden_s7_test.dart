import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenSchema = <String, dynamic>{
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

const _formulaField = <String, dynamic>{
  'key': 'total',
  'label': 'مبلغ نهایی',
  'type': 'Formula',
  'formula': {
    'op': 'chain',
    'ops': ['multiply', 'divide'],
    'inputs': ['quantity', 'unit_price', 'gross_amount'],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final vazirmatn = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([vazirmatn.load(), materialIcons.load()]);
  });

  testWidgets('computed advanced settings 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => editSchemaField(
                  context,
                  _goldenSchema,
                  _formulaField,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form_builder_s7_computed_360x800.png'),
    );
  }, tags: 'golden');
}
