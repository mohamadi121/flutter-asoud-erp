import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/widgets/template_text.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const companyToken = '{{company.company_name}}';
const labels = {
  companyToken: 'نام شرکت',
  '{{personnel.employee_name}}': 'نام پرسنل'
};

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'employee@example.test',
        fullName: 'پرسنل',
        roles: ['Employee'],
        employeeId: 'EMP-1',
        employeeName: 'سارا احمدی',
        company: 'آسود',
      );
}

Widget _ui(Widget child) => MaterialApp(
      home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child)),
    );

void main() {
  testWidgets(
      'legacy tokens have Persian chips and one editable cursor position',
      (tester) async {
    const old = 'در شرکت $companyToken و {{company.legacy_field}}';
    final controller = TemplateTextController(labels, source: old);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_ui(TextField(controller: controller)));
    expect(find.text('نام شرکت'), findsOneWidget);
    expect(find.text('فیلد ناشناخته'), findsOneWidget);
    expect(controller.source, old);

    await tester.showKeyboard(find.byType(TextField));
    final offset = 'در شرکت '.length;
    controller.selection = TextSelection.collapsed(offset: offset);
    controller.insertToken('{{personnel.employee_name}}');
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.source,
        'در شرکت {{personnel.employee_name}}$companyToken و {{company.legacy_field}}');
    final inserted = controller.value;
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: inserted.text.replaceRange(offset, offset + 1, ''),
      selection: TextSelection.collapsed(offset: offset),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.source, old);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.value.text, inserted.text);
    controller.selection =
        TextSelection(baseOffset: offset, extentOffset: offset + 1);
    controller.insertToken(companyToken);
    await tester.pump();
    expect(controller.source,
        'در شرکت $companyToken$companyToken و {{company.legacy_field}}');
    expect(tester.takeException(), isNull);
  });

  test(
      'rendering substitutes values and never prints a known or unknown technical key',
      () {
    final out = renderTemplateText(
      'شرکت $companyToken، {{personnel.employee_name}}، {{company.legacy_field}}',
      labels,
      {companyToken: 'آسود'},
    );
    expect(out.text, 'شرکت آسود، —، —');
    expect(out.missing, {'نام پرسنل', 'فیلد ناشناخته در متن قالب'});
  });

  testWidgets(
      'introduction request review uses authorised employee and entered recipient',
      (tester) async {
    final schema = <String, dynamic>{
      'kind': 'Request',
      'title': 'درخواست معرفی‌نامه',
      'review_text': '{{form.employee}} خطاب به {{form.recipient}}',
      'sections': [
        {
          'id': 'main',
          'title': 'اطلاعات',
          'fields': [
            {
              'key': 'employee',
              'label': 'نام پرسنل',
              'type': 'Text',
              'readonly': true,
              'default_source': 'employee',
              'default': 'EMP-1'
            },
            {'key': 'recipient', 'label': 'نام مرجع گیرنده', 'type': 'Text'},
          ]
        }
      ],
    };
    final repository = FormRepository(_Client(), 'آسود');
    await tester.pumpWidget(_ui(_ReviewForm(
      schema: schema,
      repository: repository,
    )));
    await tester.pumpAndSettle();
    final recipient = find.widgetWithText(TextField, 'نام مرجع گیرنده');
    await tester.enterText(recipient, 'بانک');
    await tester.pumpAndSettle();
    expect(find.text('سارا احمدی خطاب به بانک'), findsOneWidget);
    expect(find.text('درج فیلد در متن'), findsNothing);
  });
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.schema, required this.repository});
  final FormMap schema;
  final FormRepository repository;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  FormMap values = {};
  @override
  Widget build(BuildContext context) => Form(
        child: FormFieldsView(
            schema: widget.schema,
            values: values,
            repository: widget.repository,
            onChanged: (v) => setState(() => values = v)),
      );
}
