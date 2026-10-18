import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';

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

  testWidgets('table advanced properties 360x800 golden', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final field = <String, dynamic>{
      'key': 'items',
      'label': 'اقلام درخواست خرید',
      'type': 'Table',
      'orientation': 'horizontal',
      'columns': [
        {'key': 'c_item', 'label': 'شرح کالا', 'type': 'Text', 'required': true},
        {'key': 'c_qty', 'label': 'تعداد', 'type': 'Integer', 'required': true},
        {'key': 'c_price', 'label': 'قیمت واحد', 'type': 'Money', 'required': true},
        {'key': 'c_total', 'label': 'مبلغ ردیف', 'type': 'Formula'},
      ],
    };
    final schema = <String, dynamic>{
      'name': 'purchase_request',
      'label': 'درخواست خرید',
      'sections': [
        {
          'key': 's_items',
          'label': 'اقلام',
          'fields': [field],
        },
      ],
    };

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(
              context,
              schema,
              field,
            ),
            child: const Text('باز کردن'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form_builder_table_advanced_360x800.png'),
    );
  }, tags: 'golden');
}
