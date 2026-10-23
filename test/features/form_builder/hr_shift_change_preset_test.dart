import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_preview_page.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_shift_change.dart';

class _ShiftChangeClient extends Fake implements FrappeApiClient {}

Widget _fieldsPreview(FormMap schema, FormMap values, Size size) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: FormFieldsView(
                  schema: schema,
                  values: values,
                  onChanged: (_) {},
                  repository: FormRepository(_ShiftChangeClient(), 'شرکت آزمون'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

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
    expect(fields.firstWhere((field) => field['key'] == 'change_type')['style'], 'radio');
    expect(fields.firstWhere((field) => field['key'] == 'duration_mode')['style'], 'radio');
    expect(fields.firstWhere((field) => field['key'] == 'end_date')['after_or_equal'], 'start_date');
    expect(fields.firstWhere((field) => field['key'] == 'end_date')['after_or_equal_message'], 'تاریخ پایان نباید قبل از تاریخ شروع باشد.');
    expect(fields.firstWhere((field) => field['key'] == 'requested_shift').containsKey('source'), isFalse);
    expect(fields.firstWhere((field) => field['key'] == 'requested_shift')['help'], contains('نام یا شناسه شیفت'));
    expect(fields.firstWhere((field) => field['key'] == 'applicant_position')['default_source'], 'designation');
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

  test('داده ساختار تغییر شیفت برای اعتبارسنجی سرور ذخیره می‌شود', () {
    Directory('/tmp/claude-1000').createSync(recursive: true);
    File('/tmp/claude-1000/preset-shift-change.json')
        .writeAsStringSync(jsonEncode(hrShiftChangePreset()));
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
    final values = evaluatedValues(schema, <String, dynamic>{
      ...rangeSwapOther,
      'change_date': '2026-10-23',
      'start_date': '2026-10-24',
      'end_date': '2026-10-25',
      'exchange_colleague': 'EMP-002',
      'reason_description': 'شرح',
    });
    expect(values.containsKey('change_date'), isFalse);
    final selfChange = evaluatedValues(schema, <String, dynamic>{
      'change_type': 'self_change',
      'duration_mode': 'single_day',
      'reason': 'personal',
      'exchange_colleague': 'EMP-002',
    });
    expect(selfChange.containsKey('exchange_colleague'), isFalse);
  });

  testWidgets('پایان بازه پیش از شروع رد می‌شود و چیدمان RTL در موبایل سرریز ندارد', (tester) async {
    final values = <String, dynamic>{
      'change_type': 'self_change',
      'duration_mode': 'date_range',
      'start_date': '2026-10-25',
      'end_date': '2026-10-24',
      'requested_shift': 'شیفت عصر',
      'reason': 'personal',
    };
    for (final size in const [Size(320, 640), Size(390, 844), Size(430, 932)]) {
      await tester.pumpWidget(_fieldsPreview(schema, values, size));
      await tester.pump();
      expect((tester.state<FormState>(find.byType(Form)).validate()), isFalse);
      await tester.pump();
      expect(find.text('تاریخ پایان نباید قبل از تاریخ شروع باشد.'), findsOneWidget);
      expect(find.byType(OverflowBar), findsNothing);
      expect(tester.takeException(), isNull);
    }
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

  testWidgets('تاریخ تغییر مخفی در حالت بازه مانع اعتبارسنجی نمی‌شود', (tester) async {
    final values = <String, dynamic>{
      'change_type': 'self_change',
      'duration_mode': 'date_range',
      'start_date': '2026-10-24',
      'end_date': '2026-10-26',
      'requested_shift': 'شیفت عصر',
      'reason': 'personal',
    };
    await tester.pumpWidget(_fieldsPreview(schema, values, const Size(390, 844)));
    await tester.pump();
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    expect(evaluatedValues(schema, values).containsKey('change_date'), isFalse);
    final single = {...values, 'duration_mode': 'single_day'}..remove('start_date');
    await tester.pumpWidget(_fieldsPreview(schema, single, const Size(390, 844)));
    await tester.pump();
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
  });

  test('کارت گردش و یادآوری پیش‌نمایش خنثی و بدون کلیدهای ناشناس‌اند', () {
    final fields = schemaFields(schema);
    String note(String key) => fields.firstWhere((f) => f['key'] == key)['default'] as String;
    expect(note('workflow_note'), 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.');
    expect(note('preview_notice'),
        'این صفحه پیش‌نمایش درخواست تغییر شیفت است. ثبت یا تأیید درخواست به‌تنهایی برنامه کاری را تغییر نمی‌دهد.');
    final keys = fields.map((f) => f['key']);
    expect(keys, isNot(contains('current_shift')));
    expect(keys, isNot(contains('colleague_schedule_note')));
    for (final f in fields) {
      expect(f.containsKey('system_source'), isFalse);
      expect(f.containsKey('source_mode'), isFalse);
    }
  });
}
