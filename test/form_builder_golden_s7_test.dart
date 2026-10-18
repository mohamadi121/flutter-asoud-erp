import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/field_sheet/advanced/computed/formula_advanced_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FormulaAdvancedConfig(
              field: const {
                'key': 'total',
                'label': 'مبلغ نهایی',
                'type': 'Formula',
                'formula': {
                  'op': 'multiply',
                  'inputs': ['quantity', 'unit_price']
                },
              },
              schema: const {
                'title': 'فرم خرید',
                'sections': [
                  {
                    'fields': [
                      {'key': 'quantity', 'label': 'تعداد', 'type': 'Integer'},
                      {
                        'key': 'unit_price',
                        'label': 'قیمت واحد',
                        'type': 'Money'
                      },
                    ]
                  },
                ],
                'rules': [],
              },
              fieldOptions: const {
                'quantity': 'تعداد',
                'unit_price': 'قیمت واحد'
              },
              onChanged: _ignore,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form_builder_s7_computed_360x800.png'),
    );
  }, tags: 'golden');
}

void _ignore(Map<String, dynamic> _) {}
