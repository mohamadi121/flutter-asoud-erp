import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_salary_advance.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreviewHarness extends StatefulWidget {
  const _PreviewHarness({required this.schema, required this.values});

  final FormMap schema;
  final FormMap values;

  @override
  State<_PreviewHarness> createState() => _PreviewHarnessState();
}

class _PreviewHarnessState extends State<_PreviewHarness> {
  late FormMap values = {...widget.values};
  final key = GlobalKey<FormState>();

  void update(FormMap updated) => setState(() => values = updated);

  @override
  Widget build(BuildContext context) => Form(
        key: key,
        child: FormFieldsView(
          schema: widget.schema,
          values: values,
          repository: FormRepository(_NoNetworkClient(), 'شرکت آزمون'),
          onChanged: update,
        ),
      );
}

class _NoNetworkClient extends Fake implements FrappeApiClient {}

void main() {
  final schema = hrSalaryAdvancePreset();

  test('ساختار الگوی مساعده شناسه‌ها، برچسب‌ها و قوانین معتبر دارد', () {
    final fields = schemaFields(schema);

    expect(schemaProblems(schema), isEmpty);
    expect(fields.map((field) => field['key']).toSet().length, fields.length);
    expect(schema['title'], 'درخواست مساعده');
    expect(schema['module'], 'HR');
    expect(formPresets('Request').where((preset) => preset['title'] == 'درخواست مساعده'), hasLength(1));
    expect(fields.where((field) => field['required'] == true).map((field) => field['key']),
        containsAll(['requested_amount', 'advance_reason', 'repayment_method']));
    expect(fields.map((field) => field['label']),
        containsAll(['نام و نام خانوادگی', 'مبلغ مساعده درخواستی', 'دلیل درخواست مساعده', 'شرح دلیل درخواست', 'روش تسویه پیشنهادی', 'تعداد اقساط پیشنهادی', 'پیوست‌ها']));
    expect(fields.map((field) => field['key']), isNot(contains('approved_amount')));
    expect(fields.map((field) => field['key']), isNot(contains('paid_amount')));
    expect(schema['sections'].map((section) => section['title']),
        containsAll(['مشخصات متقاضی', 'مشخصات مساعده', 'پیشنهاد نحوه تسویه', 'پیوست‌ها', 'گردش تأیید', 'بررسی نهایی و ارسال']));
  });

  testWidgets('پیش‌نمایش مساعده در ۳۶۰×۸۰۰ شرط‌ها و اعتبارسنجی فیلدهای قابل نمایش را اجرا می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: _PreviewHarness(schema: schema, values: const {}))),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('شرح دلیل درخواست *'), findsNothing);
    expect(find.text('تعداد اقساط پیشنهادی *'), findsNothing);
    expect(find.text('مبلغ تقریبی هر قسط'), findsNothing);
    expect(tester.takeException(), isNull);

    final state = tester.state<_PreviewHarnessState>(find.byType(_PreviewHarness));
    expect(state.key.currentState!.validate(), isFalse);

    state.update({
        'requested_amount': '12000000',
        'advance_reason': 'other',
        'repayment_method': 'payroll_deduction',
        'installment_count': 'installments_3',
      });
    await tester.pumpAndSettle();

    expect(find.text('شرح دلیل درخواست *'), findsOneWidget);
    expect(find.text('تعداد اقساط پیشنهادی *'), findsOneWidget);
    expect(find.text('مبلغ تقریبی هر قسط'), findsOneWidget);
    expect(find.text('4000000'), findsOneWidget);
    expect(state.key.currentState!.validate(), isFalse);

    state.update({...state.values, 'reason_detail': 'نیاز ضروری خانوادگی'});
    await tester.pumpAndSettle();
    expect(state.key.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });
}
