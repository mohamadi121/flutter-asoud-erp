import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}

Widget _form(FormMap schema, FormMap values) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Form(
            child: FormFieldsView(
              schema: schema,
              values: values,
              onChanged: (_) {},
              repository: FormRepository(_Client(), 'شرکت'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('راهنما، توضیح بخش و انتخاب رادیویی در اندازه موبایل دیده می‌شوند', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final schema = <String, dynamic>{
      'sections': [
        {
          'title': 'بخش رنگی', 'description': 'توضیح بخش', 'icon': 'event', 'color': '#F0FDF4',
          'fields': [
            {'key': 'kind', 'type': 'Select', 'label': 'نوع', 'style': 'radio', 'help': 'راهنمای انتخاب', 'options': [{'id': 'a', 'label': 'الف'}]},
          ],
        },
      ],
    };
    await tester.pumpWidget(_form(schema, {}));
    expect(find.text('توضیح بخش'), findsOneWidget);
    expect(find.text('راهنمای انتخاب'), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('حداقل ردیف جدول اعتبارسنجی می‌شود', (tester) async {
    final key = GlobalKey<FormState>();
    final schema = <String, dynamic>{'sections': [{'fields': [{'key': 'rows', 'type': 'Table', 'label': 'ردیف‌ها', 'required': true, 'min_rows': 2, 'columns': []}]}]};
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Form(
              key: key,
              child: FormFieldsView(
                schema: schema,
                values: {},
                onChanged: (_) {},
                repository: FormRepository(_Client(), 'شرکت'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    expect(find.text('حداقل ۲ ردیف لازم است.'), findsOneWidget);
  });
}
