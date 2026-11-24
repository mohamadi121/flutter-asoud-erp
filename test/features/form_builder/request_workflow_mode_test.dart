import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_editor/editor_info_step.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';

void main() {
  FormMap request() => {
        'kind': 'Request', 'title': 'فرم آزمون', 'module': 'General',
        'sections': [
          {'id': 'main', 'fields': [
            {'key': 'note', 'label': 'توضیح', 'type': 'Text'},
          ]},
        ],
      };

  test('legacy and explicit modes validate without assigning a new policy', () {
    final schema = request();
    expect(schemaProblems(schema), isEmpty);
    expect(schema.containsKey('workflow_mode'), isFalse);
    schema['workflow_mode'] = 'Fixed';
    expect(schemaProblems(schema), contains(contains('گردش مشخص')));
    schema['workflow'] = 'chosen';
    expect(schemaProblems(schema), isEmpty);
    for (final mode in ['Conditional', 'RecordOnly']) {
      schema['workflow_mode'] = mode;
      expect(schemaProblems(schema), isEmpty); // Drafts; server gates publication.
    }
    schema['workflow_mode'] = false;
    expect(schemaProblems(schema), contains(contains('روش اتصال')));
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('blocked record-only draft is preserved but not offered at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final schema = request()..['workflow_mode'] = 'RecordOnly';
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: StatefulBuilder(
          builder: (context, update) => EditorInfoStep(
            schema: schema, options: const {}, change: update,
          ),
        ))),
      )));
      await tester.tap(find.text('اتصال به گردش‌کار (اختیاری)'));
      await tester.pumpAndSettle();
      expect(schema['workflow_mode'], 'RecordOnly');
      expect(find.textContaining('سیاست معتبر'), findsOneWidget);
      await tester.ensureVisible(find.text('روش اتصال مجاز را انتخاب کنید'));
      await tester.tap(find.text('روش اتصال مجاز را انتخاب کنید'));
      await tester.pumpAndSettle();
      expect(find.text('فقط ثبت فرم'), findsNothing);
      await tester.tap(find.text('انتخاب بر اساس شرط').last);
      await tester.pumpAndSettle();
      expect(schema['workflow_mode'], 'Conditional');
      expect(tester.takeException(), isNull);
    });

    testWidgets('request workflow intent persists at $width RTL', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final schema = request();
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(
            child: StatefulBuilder(builder: (context, update) => EditorInfoStep(
              schema: schema,
              options: {'workflows': [
                {'name': 'chosen', 'title': 'گردش منتخب', 'fields': []},
              ]},
              change: update,
            )),
          )),
        ),
      ));
      expect(schema.containsKey('workflow_mode'), isFalse);
      await tester.tap(find.text('اتصال به گردش‌کار (اختیاری)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('گردش‌کار انتخاب نشده است'));
      await tester.tap(find.text('گردش‌کار انتخاب نشده است'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('گردش منتخب').last);
      await tester.pumpAndSettle();
      expect(schema['workflow'], 'chosen');
      expect(schema['workflow_mode'], 'Fixed');
      await tester.ensureVisible(find.text('گردش مشخص'));
      await tester.tap(find.text('گردش مشخص'));
      await tester.pumpAndSettle();
      expect(find.text('فقط ثبت فرم'), findsNothing);
      await tester.tap(find.text('انتخاب بر اساس شرط').last);
      await tester.pumpAndSettle();
      expect(schema['workflow_mode'], 'Conditional');
      expect(schema['workflow'], 'chosen'); // Ignored by server, not rewritten.
      expect(tester.takeException(), isNull);
    });
  }
}
