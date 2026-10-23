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
    await tester.pump();
    expect(find.text('حداقل ۲ ردیف لازم است.'), findsOneWidget);
  });

  testWidgets('جدول الزامی بدون حداقل ردیف نیز اعتبارسنجی می‌شود', (tester) async {
    final key = GlobalKey<FormState>();
    final schema = <String, dynamic>{'sections': [{'fields': [{'key': 'rows', 'type': 'Table', 'label': 'ردیف‌ها', 'required': true, 'columns': []}]}]};
    await tester.pumpWidget(
      MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(
        body: Form(key: key, child: FormFieldsView(
          schema: schema,
          values: {},
          onChanged: (_) {},
          repository: FormRepository(_Client(), 'شرکت'),
        )),
      ))),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('حداقل ۱ ردیف لازم است.'), findsOneWidget);
  });

  testWidgets('دریافت خودکار برای همه ورودی‌ها مقدار ذخیره نمی‌کند', (tester) async {
    final schema = <String, dynamic>{'sections': [{'fields': [
      for (final type in ['Text', 'Money', 'Date', 'Time', 'Select', 'Link', 'File'])
        {'key': type, 'type': type, 'label': type, 'default_source': 'employee', if (type == 'Select') 'options': [{'id': 'one', 'label': 'یک'}]},
    ]}]};
    await tester.pumpWidget(_form(schema, {}));
    expect(find.text('دریافت خودکار'), findsNWidgets(7));
    final select = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(select.initialValue, isNull, reason: 'placeholder must not become a stored selection');
  });

  testWidgets('فرم در ۳۹۰ و ۴۳۰ پیکسل راست‌به‌چپ سرریز ندارد', (tester) async {
    final schema = <String, dynamic>{'sections': [{'title': 'نمایش موبایل', 'description': 'راهنمای بخش', 'fields': [{'key': 'value', 'type': 'Text', 'label': 'مقدار', 'help': 'راهنما'}]}]};
    for (final width in [390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_form(schema, {}));
      expect(find.byType(Directionality), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('بخش جمع‌شونده بسته فیلدها را پنهان می‌کند و با لمس سرتیتر نشان می‌دهد', (tester) async {
    final schema = <String, dynamic>{'sections': [{'title': 'بخش جمع', 'collapsible': true, 'collapsed': true, 'fields': [{'key': 'v', 'type': 'Text', 'label': 'مقدار پنهان'}]}]};
    await tester.pumpWidget(_form(schema, {}));
    expect(find.text('مقدار پنهان'), findsNothing);
    await tester.tap(find.text('بخش جمع'));
    await tester.pump();
    expect(find.text('مقدار پنهان'), findsOneWidget);
  });

  test('نام‌های آیکن بخش‌های پیش‌تنظیم به آیکن مشخص نگاشت می‌شوند', () {
    const names = ['person', 'swap_horiz', 'inventory_2', 'event', 'notes', 'badge', 'assignment', 'school', 'calendar', 'payments', 'clock', 'schedule', 'edit_note', 'attach_file', 'account_tree', 'fact_check', 'box', 'wallet', 'assignment_turned_in', 'download'];
    for (final name in names) {
      expect(sectionIconForName(name), isNot(Icons.folder_outlined), reason: name);
    }
    expect(sectionIconForName('unknown'), Icons.folder_outlined);
  });
}
