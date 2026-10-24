import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_preview_page.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_settlement.dart';

class _PreviewClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'employee@asoud.local',
        fullName: 'کارمند آزمون',
        roles: ['Employee'],
        company: 'شرکت نمونه آسود',
      );
}

void main() {
  test('schema درخواست تسویه‌حساب شناسه‌ها، برچسب‌ها و قانون‌ها را حفظ می‌کند', () {
    final schema = hrSettlementPreset();
    final fields = schemaFields(schema);
    final keys = fields.map((field) => field['key']).toList();

    expect(schema['title'], 'درخواست تسویه‌حساب پرسنل');
    expect(schema.containsKey('short_title'), isFalse);
    expect(schema['module'], 'HR');
    expect(schema['icon'], 'assignment_turned_in');
    expect(schema['color'], '#1876D2');
    expect(keys.toSet().length, keys.length);
    expect(keys, containsAll([
      'applicant_employee',
      'applicant_department',
      'applicant_position',
      'applicant_joining_date',
      'settlement_reason',
      'reason_description',
      'proposed_end_date',
      'property_declaration',
      'additional_notes',
    ]));
    expect(fields.where((field) => field['readonly'] == true && field['type'] != 'Display').length, 5);
    expect(keys, isNot(contains('company')));
    expect(keys.any((key) => key.contains('office')), isFalse);
    expect(fields.firstWhere((field) => field['key'] == 'applicant_employee'), {
      'key': 'applicant_employee',
      'label': 'نام و نام خانوادگی',
      'type': 'Link',
      'readonly': true,
      'source': 'Employee',
      'default_source': 'employee',
      'span': 2,
    });
    expect(fields.firstWhere((field) => field['key'] == 'applicant_department')['default_source'], 'department');
    expect(fields.firstWhere((field) => field['key'] == 'applicant_position')['default_source'], 'designation');
    final contractStart = fields.firstWhere((field) => field['key'] == 'applicant_joining_date');
    expect(contractStart['default_source'], 'contract_start');
    expect(contractStart['label'], contains('در نبود قرارداد'));
    expect(fields.where((field) => field.containsKey('default')).map((field) => field['default']), isNot(contains('دریافت خودکار')));
    final reason = fields.singleWhere((field) => field['key'] == 'settlement_reason');
    expect(reason['required'], isTrue);
    final property = fields.singleWhere((field) => field['key'] == 'property_declaration');
    expect(property['style'], 'radio');
    expect(property['default'], 'needs_review');
    expect(schema['sections'][2]['description'], 'این انتخاب صرفاً اعلام متقاضی است. تأیید نهایی وضعیت اموال و تجهیزات توسط واحد مسئول انجام می‌شود.');
    expect(fields.singleWhere((field) => field['key'] == 'proposed_end_date')['help'], 'این تاریخ پیشنهادی است و تا زمان تأیید مراجع دارای اختیار، تاریخ قطعی پایان همکاری محسوب نمی‌شود.');
    expect(reason['options'], equals([
      {'id': 'resignation', 'label': 'استعفا'},
      {'id': 'contract_end', 'label': 'پایان قرارداد'},
      {'id': 'retirement', 'label': 'بازنشستگی'},
      {'id': 'other_termination', 'label': 'سایر موارد خاتمه همکاری'},
      {'id': 'other', 'label': 'سایر موارد'},
    ]));
    expect(schemaProblems(schema), isEmpty);
  });

  testWidgets('پیش‌نمایش ۳۶۰×۸۰۰ شرح علت را شرطی و فقط هنگام نمایش اجباری می‌کند', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    final schema = hrSettlementPreset();
    final description = schemaFields(schema)
        .singleWhere((field) => field['key'] == 'reason_description');
    expect(formFlag(description, schema, {'settlement_reason': 'other'}, 'visible'), isTrue);
    expect(formFlag(description, schema, {'settlement_reason': 'other'}, 'required'), isTrue);
    expect(formFlag(description, schema, {'settlement_reason': 'resignation'}, 'visible'), isFalse);
    expect(formFlag(description, schema, {'settlement_reason': 'resignation'}, 'required'), isFalse);

    for (final size in [const Size(320, 640), const Size(390, 844), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AsoudTheme.light,
        home: FormPreviewPage(
          schema: schema,
          repository: FormRepository(_PreviewClient(), 'شرکت نمونه آسود'),
          initialValues: {'settlement_reason': 'other', 'proposed_end_date': '2026-10-22'},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('دریافت خودکار'), findsNWidgets(5));
      expect(find.text('این تاریخ پیشنهادی است و تا زمان تأیید مراجع دارای اختیار، تاریخ قطعی پایان همکاری محسوب نمی‌شود.'), findsOneWidget);
      expect(find.text('این انتخاب صرفاً اعلام متقاضی است. تأیید نهایی وضعیت اموال و تجهیزات توسط واحد مسئول انجام می‌شود.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);

    expect(find.text('شرح علت *'), findsOneWidget);
    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pumpAndSettle();
    expect(find.text('تکمیل این فیلد الزامی است.'), findsOneWidget);

    expect(
      evaluatedValues(schema, {
        'settlement_reason': 'resignation',
        'reason_description': 'نباید پس از پنهان‌شدن باقی بماند',
      }).containsKey('reason_description'),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  test('کارت مراحل بررسی فقط یک متن خنثی است و کلید format ندارد', () {
    final schema = hrSettlementPreset();
    final fields = [
      for (final s in schema['sections'] as List)
        ...(((s as Map)['fields']) as List).cast<Map>(),
    ];
    final info = fields.singleWhere((f) => f['key'] == 'review_steps_info');
    expect(info['type'], 'Display');
    expect(info['default'], startsWith('مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.'));
    expect(fields.where((f) => f['type'] == 'Display'), hasLength(1));
    expect(schema.containsKey('format'), isFalse);
  });
}
