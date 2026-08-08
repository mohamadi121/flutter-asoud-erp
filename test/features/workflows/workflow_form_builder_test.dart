import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_form_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('فیلد معتبر به سازنده فرم اضافه می‌شود', (tester) async {
    var fields = <WorkflowFormFieldDefinition>[];
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
                body: WorkflowFormBuilder(
                  fields: fields,
                  onChanged: (next) => setState(() => fields = next),
                ),
              )),
    ));

    await tester.tap(find.text('افزودن فیلد فرم'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'عنوان فیلد *'), 'عنوان درخواست');
    await tester.enterText(
        find.widgetWithText(TextField, 'کلید فنی *'), 'request_title');
    await tester.tap(find.text('ثبت فیلد'));
    await tester.pumpAndSettle();

    expect(fields, hasLength(1));
    expect(fields.single.key, 'request_title');
    expect(find.text('عنوان درخواست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
