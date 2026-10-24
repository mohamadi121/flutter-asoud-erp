import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_leave.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_mission.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_overtime.dart';

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}

class _Harness extends StatefulWidget {
  const _Harness({required this.schema, required this.values, required this.formKey});

  final FormMap schema;
  final FormMap values;
  final GlobalKey<FormState> formKey;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late FormMap values = widget.values;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: widget.formKey,
                child: FormFieldsView(
                  schema: widget.schema,
                  values: values,
                  repository: FormRepository(_Client(), 'شرکت آزمون'),
                  onChanged: (next) => setState(() => values = next),
                ),
              ),
            ),
          ),
        ),
      );
}

Future<void> _mount(WidgetTester tester, FormMap schema, FormMap values, GlobalKey<FormState> key,
    {double width = 390}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_Harness(schema: schema, values: values, formKey: key));
  await tester.pumpAndSettle();
}

FormMap _field(FormMap schema, String key) =>
    schemaFields(schema).firstWhere((field) => field['key'] == key);

void _commonContract(FormMap Function() preset, String title) {
  final schema = preset();
  final fields = schemaFields(schema);
  expect(schema['title'], title);
  expect(schema['kind'], 'Request');
  expect(schema['module'], 'HR');
  expect(schema['schema_version'], 2);
  expect(fields.map((f) => f['key']).toSet().length, fields.length);
  expect(schemaProblems(schema), isEmpty);
  expect(formPresets('Request').where((p) => p['title'] == title), hasLength(1));
  // raw reusable form: no execution, no mapping, no fixed approver, no sample data
  expect(schema.containsKey('execution'), isFalse);
  expect(fields.where((f) => f.containsKey('execution_key')), isEmpty);
  expect(fields.where((f) => f.containsKey('system_source')), isEmpty);
  expect(fields.map((f) => f['key']), containsAll(['applicant_employee', 'applicant_department', 'applicant_position']));
  expect(_field(schema, 'applicant_employee')['default_source'], 'employee');
  expect(_field(schema, 'applicant_department')['default_source'], 'department');
  expect(_field(schema, 'applicant_position')['default_source'], 'designation');
  for (final key in ['applicant_employee', 'applicant_department', 'applicant_position']) {
    final field = _field(schema, key);
    expect(field['readonly'], isTrue);
    expect(field.containsKey('default'), isFalse);
  }
  final notice = _field(schema, 'approval_flow_notice');
  expect(notice['type'], 'Display');
  expect(notice['default'], 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.');
  for (final section in formMaps(schema['sections'])) {
    expect(formMaps(section['fields']), isNotEmpty, reason: 'بخش خالی ${section['id']}');
  }
  for (final rule in formMaps(schema['rules'])) {
    expect(fields.map((f) => f['key']), contains(rule['target']));
    for (final condition in formMaps(rule['conditions'])) {
      expect(fields.map((f) => f['key']), contains(condition['field']));
    }
  }
}

void main() {
  group('الگوی درخواست مرخصی', () {
    test('ساختار، منبع نوع مرخصی و فیلدهای حساس طبق مشخصات', () {
      _commonContract(hrLeavePreset, 'درخواست مرخصی');
      final schema = hrLeavePreset();
      final type = _field(schema, 'leave_type');
      expect((type['type'], type['source'], type['required']), ('Link', 'Leave Type', true));
      expect(type.containsKey('default'), isFalse);
      expect(_field(schema, 'from_date')['default_source'], 'today');
      expect(_field(schema, 'from_date')['required'], isTrue);
      expect(_field(schema, 'to_date')['after_or_equal'], 'from_date');
      expect(_field(schema, 'to_date')['after_or_equal_message'], 'تاریخ پایان نباید پیش از تاریخ شروع باشد.');
      final half = _field(schema, 'half_day_date');
      expect(half['after_or_equal'], 'from_date');
      expect(half['before_or_equal'], 'to_date');
      expect(half['before_or_equal_message'], 'تاریخ نیم‌روز باید در بازه درخواست باشد.');
      expect(_field(schema, 'half_day')['default'], false);
      expect(_field(schema, 'description')['max_length'], 2000);
      expect(_field(schema, 'description')['sensitive'], isTrue);
      expect(_field(schema, 'attachments')['sensitive'], isTrue);
      expect(schemaFields(schema).where((f) => f['type'] == 'Time'), isEmpty);
      expect(schemaFields(schema).where((f) => f['type'] == 'Display' && f['key'] != 'approval_flow_notice'), isEmpty);
    });

    testWidgets('نیم‌روز فقط با کلید روشن نمایان و الزامی است و باید داخل بازه باشد', (tester) async {
      final schema = hrLeavePreset();
      final key = GlobalKey<FormState>();
      final values = <String, dynamic>{
        'leave_type': 'مرخصی استحقاقی',
        'from_date': '2026-10-23',
        'to_date': '2026-10-25',
        'half_day': false,
      };
      await _mount(tester, schema, values, key);
      expect(find.text('تاریخ نیم‌روز'), findsNothing);
      expect(key.currentState!.validate(), isTrue);

      values
        ..['half_day'] = true
        ..['half_day_date'] = '2026-10-27';
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, schema, values, key);
      expect(find.text('تاریخ نیم‌روز *'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('تاریخ نیم‌روز باید در بازه درخواست باشد.'), findsOneWidget);

      values['half_day_date'] = '2026-10-24';
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, schema, values, key);
      expect(key.currentState!.validate(), isTrue);

      values
        ..['to_date'] = '2026-10-20'
        ..['half_day'] = false;
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, schema, values, key);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('تاریخ پایان نباید پیش از تاریخ شروع باشد.'), findsOneWidget);
    });
  });

  group('الگوی درخواست مأموریت', () {
    test('ساختار، شیفت اختیاری و نبود گزینه تعطیلات', () {
      _commonContract(hrMissionPreset, 'درخواست مأموریت');
      final schema = hrMissionPreset();
      expect(_field(schema, 'destination')['required'], isTrue);
      expect(_field(schema, 'destination')['max_length'], 250);
      expect(_field(schema, 'purpose')['required'], isTrue);
      expect(_field(schema, 'purpose')['max_length'], 2000);
      final shift = _field(schema, 'shift');
      expect((shift['type'], shift['source']), ('Link', 'Shift Type'));
      expect(shift['required'], isNull);
      expect(schemaFields(schema).map((f) => f['key']), isNot(contains('include_holidays')));
      expect(_field(schema, 'notes')['sensitive'], isTrue);
      expect(_field(schema, 'half_day_date')['before_or_equal'], 'to_date');
      expect(formPresets('Request').where((p) => p['title'] == 'درخواست مرخصی'), hasLength(1));
    });

    testWidgets('مقصد و هدف الزامی‌اند و نیم‌روز بیرون بازه رد می‌شود', (tester) async {
      final schema = hrMissionPreset();
      final key = GlobalKey<FormState>();
      final values = <String, dynamic>{
        'from_date': '2026-10-23',
        'to_date': '2026-10-24',
        'half_day': true,
        'half_day_date': '2026-10-30',
      };
      await _mount(tester, schema, values, key);
      expect(find.text('مقصد مأموریت *'), findsOneWidget);
      expect(find.text('هدف مأموریت *'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('تاریخ نیم‌روز باید در بازه درخواست باشد.'), findsOneWidget);
    });
  });

  group('الگوی درخواست اضافه‌کار', () {
    test('ساختار، روز بعد فقط برای ساعت پایان و بدون فیلد جعلی مدت', () {
      _commonContract(hrOvertimePreset, 'درخواست اضافه‌کار');
      final schema = hrOvertimePreset();
      expect(_field(schema, 'work_date')['default_source'], 'today');
      expect(_field(schema, 'start_time')['next_day_allowed'], isNull);
      final end = _field(schema, 'end_time');
      expect(end['next_day_allowed'], isTrue);
      expect(end['time_after'], 'start_time');
      expect(end['time_after_message'], 'ساعت پایان باید پس از ساعت شروع باشد.');
      expect(schemaFields(schema).where((f) => f['required'] == true).map((f) => f['key']),
          containsAll(['work_date', 'start_time', 'end_time', 'purpose']));
      expect(_field(schema, 'notes')['sensitive'], isTrue);
      expect(schemaFields(schema).map((f) => f['key']), isNot(contains('duration')));
    });

    testWidgets('پایان پیش از شروع رد می‌شود و عبور از نیمه‌شب با «روز بعد» پذیرفته است', (tester) async {
      final schema = hrOvertimePreset();
      final key = GlobalKey<FormState>();
      final values = <String, dynamic>{
        'work_date': '2026-10-23',
        'start_time': '22:00',
        'end_time': '01:00',
        'purpose': 'استقرار',
      };
      await _mount(tester, schema, values, key);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('ساعت پایان باید پس از ساعت شروع باشد.'), findsOneWidget);

      values['end_time__next_day'] = true;
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, schema, values, key);
      expect(key.currentState!.validate(), isTrue);
    });
  });

  for (final entry in {
    'مرخصی': hrLeavePreset,
    'مأموریت': hrMissionPreset,
    'اضافه‌کار': hrOvertimePreset,
  }.entries) {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('${entry.key} در عرض ${width.toInt()} بدون سرریز و در حالت پیش‌نمایش بدون سرور باز می‌شود',
          (tester) async {
        final key = GlobalKey<FormState>();
        await _mount(tester, entry.value(), {}, key, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('مسیر بررسی'), findsOneWidget);
      });
    }
  }
}
