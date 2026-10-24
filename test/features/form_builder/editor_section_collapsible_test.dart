import 'package:asoud_erp/features/form_builder/form_editor/editor_design_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('سوییچ «قابل جمع شدن» مقدار collapsible بخش را ثبت می‌کند', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final section = <String, dynamic>{'title': 'اطلاعات', 'fields': <Map<String, dynamic>>[]};
    final schema = <String, dynamic>{'sections': [section]};
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: EditorDesignStep(
                schema: schema,
                change: (fn) => setState(fn),
                onEditField: (s, [i]) async {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final tile = find.text('قابل جمع شدن');
    await tester.ensureVisible(tile);
    expect((schema['sections'] as List).first['collapsible'], isNot(true));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect((schema['sections'] as List).first['collapsible'], isTrue);
    expect(tester.takeException(), isNull);
  });
}
