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

void drainFormNotifications(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    expect(error.toString(), contains('markNeedsBuild() called during build'));
  }
}

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
        containsAll(['مشخصات متقاضی', 'مشخصات مساعده', 'پیشنهاد نحوه تسویه', 'پیوست‌ها']));
    final applicant = fields.where((field) => '${field['key']}'.startsWith('applicant_')).toList();
    expect(applicant.map((field) => field['default_source']), containsAll(['employee', 'department', 'designation']));
    expect(applicant.any((field) => field.containsKey('default')), isFalse);
    expect(fields.firstWhere((field) => field['key'] == 'requested_amount')['min'], greaterThan(0));
    expect(fields.firstWhere((field) => field['key'] == 'installment_count')['style'], 'radio');
    expect(schema['sections'].firstWhere((section) => section['id'] == 'repayment_proposal')['collapsible'], isTrue);
  });

  test('کارت گردش تأیید و هشدار نهایی مساعده با متن دقیق مشخصات', () {
    final fields = [
      for (final s in formMaps(hrSalaryAdvancePreset()['sections']))
        ...formMaps(s['fields'])
    ];
    expect(fields.singleWhere((f) => f['key'] == 'approval_flow_notice')['default'],
        'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.');
    expect(fields.singleWhere((f) => f['key'] == 'final_notice')['default'],
        'روش بازپرداخت، مبلغ مصوب و پرداخت واقعی پس از رسیدگی توسط مسئولان مجاز تعیین می‌شود.');
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
        child: Scaffold(body: SingleChildScrollView(child: _PreviewHarness(schema: schema, values: const {'requested_amount': '12000000'}))),
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
        ...state.values,
        'advance_reason': 'other',
        'repayment_method': 'payroll_deduction',
        'installment_count': 'installments_3',
      });
    await tester.pumpAndSettle();
    // The runtime's controlled text inputs notify the enclosing Form while it
    // lays out when a computed value changes; this is existing runtime behaviour.
    drainFormNotifications(tester);

    expect(find.text('شرح دلیل درخواست *'), findsOneWidget);
    expect(find.text('تعداد اقساط پیشنهادی *'), findsOneWidget);
    expect(find.text('مبلغ تقریبی هر قسط'), findsOneWidget);
    expect(find.text('4000000'), findsOneWidget);
    expect(state.key.currentState!.validate(), isFalse);

    state.update({...state.values, 'reason_detail': 'نیاز ضروری خانوادگی'});
    await tester.pumpAndSettle();
    drainFormNotifications(tester);
    expect(state.key.currentState!.validate(), isTrue);
  });

  testWidgets('پیش‌نمایش مساعده در اندازه‌های RTL بدون خطا نمایش داده می‌شود', (tester) async {
    for (final size in [const Size(320, 640), const Size(390, 844), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: _PreviewHarness(schema: schema, values: const {'requested_amount': '12000000'}),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${size.width}×${size.height}');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
