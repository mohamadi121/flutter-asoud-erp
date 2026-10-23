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
    expect(schema['short_title'], 'درخواست تسویه‌حساب');
    expect(schema['module'], 'HR');
    expect(schema['icon'], 'assignment_turned_in');
    expect(schema['color'], '#1876D2');
    expect(keys.toSet().length, keys.length);
    expect(keys, containsAll([
      'employee_full_name',
      'employee_code',
      'organization_unit',
      'organization_position',
      'employment_start_date',
      'settlement_reason',
      'reason_description',
      'proposed_end_date',
      'property_declaration',
      'additional_notes',
    ]));
    expect(fields.where((field) => field['readonly'] == true).length, 5);
    expect(keys, isNot(contains('company')));
    final reason = fields.singleWhere((field) => field['key'] == 'settlement_reason');
    expect(reason['required'], isTrue);
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
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final schema = hrSettlementPreset();
    final description = schemaFields(schema)
        .singleWhere((field) => field['key'] == 'reason_description');
    expect(formFlag(description, schema, {'settlement_reason': 'other'}, 'visible'), isTrue);
    expect(formFlag(description, schema, {'settlement_reason': 'other'}, 'required'), isTrue);
    expect(formFlag(description, schema, {'settlement_reason': 'resignation'}, 'visible'), isFalse);
    expect(formFlag(description, schema, {'settlement_reason': 'resignation'}, 'required'), isFalse);

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
}
