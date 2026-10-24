import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_widgets.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_salary_advance.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_settlement.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_shift_change.dart';

Set<String> _sensitiveKeys(FormMap schema) => {
      for (final field in schemaFields(schema))
        if (field['sensitive'] == true) field['key'] as String,
    };

void main() {
  test('مساعده: دلیل، شرح، توضیحات و پیوست درمانی محرمانه است', () {
    expect(_sensitiveKeys(hrSalaryAdvancePreset()),
        {'advance_reason', 'reason_detail', 'additional_notes', 'attachments'});
  });

  test('تسویه: علت و شرح علت و توضیحات محرمانه است', () {
    expect(_sensitiveKeys(hrSettlementPreset()),
        {'settlement_reason', 'reason_description', 'additional_notes'});
  });

  test('تغییر شیفت: شرح علت و توضیحات تکمیلی محرمانه است', () {
    expect(_sensitiveKeys(hrShiftChangePreset()), {'reason_description', 'additional_notes'});
  });

  test('مبلغ و تاریخ‌ها محرمانه نیستند', () {
    for (final schema in [hrSalaryAdvancePreset(), hrSettlementPreset(), hrShiftChangePreset()]) {
      for (final field in schemaFields(schema)) {
        if (['Money', 'Date', 'Display'].contains(field['type'])) {
          expect(field['sensitive'], isNull, reason: field['key'] as String);
        }
      }
    }
  });

  testWidgets('ویرایشگر پرچم محرمانه فیلد پیش‌فرض را نشان می‌دهد و حفظ می‌کند', (tester) async {
    final field = schemaFields(hrSalaryAdvancePreset()).firstWhere((f) => f['key'] == 'reason_detail');
    FormMap? result;
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await editSchemaField(context, blankSchema('Request'), {...field}),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پیشرفته'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('اطلاعات حساس'), 180, scrollable: find.byType(Scrollable).last);
    final tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'اطلاعات حساس'));
    expect(tile.value, isTrue);
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(result?['sensitive'], isTrue);
    expect(tester.takeException(), isNull);
  });
}
