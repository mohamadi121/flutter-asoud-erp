import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_preview_page.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_shift_change.dart';

class _ShiftChangeClient extends Fake implements FrappeApiClient {}

void main() {
  final schema = hrShiftChangePreset();

  test('طرح تغییر شیفت شناسه‌ها، برچسب‌ها و قوانین معتبر دارد', () {
    final fields = schemaFields(schema);
    final keys = fields.map((field) => field['key']).toList();

    expect(schema['schema_version'], 2);
    expect(schema['kind'], 'Request');
    expect(schema['title'], 'درخواست تغییر شیفت');
    expect(keys.toSet().length, keys.length);
    expect(
      fields.where((field) => field['required'] == true).map((field) => field['key']),
      containsAll(<String>[
        'applicant_employee',
        'change_type',
        'duration_mode',
        'change_date',
        'requested_shift',
        'reason',
      ]),
    );
    expect(
      fields.firstWhere((field) => field['key'] == 'change_type')['options'],
      equals(<FormMap>[
        {'id': 'self_change', 'label': 'تغییر شیفت خودم'},
        {'id': 'swap_with_colleague', 'label': 'جابه‌جایی شیفت با همکار'},
      ]),
    );
    expect(
      fields.firstWhere((field) => field['key'] == 'reason')['options'],
      equals(<FormMap>[
        {'id': 'personal', 'label': 'امور شخصی'},
        {'id': 'medical', 'label': 'دلایل درمانی'},
        {'id': 'family', 'label': 'مسائل خانوادگی'},
        {'id': 'other', 'label': 'سایر موارد'},
      ]),
    );
    expect(schemaProblems(schema), isEmpty);
    for (final rule in schema['rules'] as List<FormMap>) {
      expect(keys, contains(rule['target']));
      for (final condition in rule['conditions'] as List<FormMap>) {
        expect(keys, contains(condition['field']));
      }
    }
  });

  test('قوانین تغییر شیفت فیلدهای مرتبط را نمایش و الزام می‌کنند', () {
    final fields = schemaFields(schema);
    FormMap field(String key) => fields.firstWhere((field) => field['key'] == key);

    const singleDay = <String, dynamic>{
      'change_type': 'self_change',
      'duration_mode': 'single_day',
      'reason': 'personal',
    };
    expect(formFlag(field('change_date'), schema, singleDay, 'visible'), isTrue);
    expect(formFlag(field('start_date'), schema, singleDay, 'visible'), isFalse);
    expect(formFlag(field('exchange_colleague'), schema, singleDay, 'visible'), isFalse);
    expect(formFlag(field('reason_description'), schema, singleDay, 'required'), isFalse);

    const rangeSwapOther = <String, dynamic>{
      'change_type': 'swap_with_colleague',
      'duration_mode': 'date_range',
      'reason': 'other',
    };
    expect(formFlag(field('change_date'), schema, rangeSwapOther, 'visible'), isFalse);
    expect(formFlag(field('start_date'), schema, rangeSwapOther, 'required'), isTrue);
    expect(formFlag(field('end_date'), schema, rangeSwapOther, 'required'), isTrue);
    expect(formFlag(field('exchange_colleague'), schema, rangeSwapOther, 'required'), isTrue);
    expect(formFlag(field('reason_description'), schema, rangeSwapOther, 'required'), isTrue);
  });

  testWidgets('پیش‌نمایش تغییر شیفت در موبایل شرط و الزام فیلد را رعایت می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: FormPreviewPage(
        key: const ValueKey('other-reason'),
        schema: schema,
        repository: FormRepository(_ShiftChangeClient(), 'شرکت آزمون'),
        initialValues: const <String, dynamic>{
          'applicant_employee': 'EMP-001',
          'applicant_department': 'HR',
          'change_type': 'self_change',
          'duration_mode': 'single_day',
          'change_date': '2026-10-23',
          'requested_shift': 'SHIFT-001',
          'reason': 'other',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('شرح علت *'), findsOneWidget);
    expect(find.text('تاریخ شروع'), findsNothing);
    expect(find.text('همکار طرف جابه‌جایی'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pumpAndSettle();
    expect(find.text('لطفاً خطاهای فیلدهای فرم را برطرف کنید.'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: FormPreviewPage(
        key: const ValueKey('personal-reason'),
        schema: schema,
        repository: FormRepository(_ShiftChangeClient(), 'شرکت آزمون'),
        initialValues: const <String, dynamic>{
          'applicant_employee': 'EMP-001',
          'applicant_department': 'HR',
          'change_type': 'self_change',
          'duration_mode': 'single_day',
          'change_date': '2026-10-23',
          'requested_shift': 'SHIFT-001',
          'reason': 'personal',
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('شرح علت *'), findsNothing);

    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pumpAndSettle();
    expect(
      find.text('ساختار و مقادیر فرم با موفقیت در حالت آزمایشی اعتبارسنجی شدند. هیچ داده‌ای در سرور ثبت نگردید.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
