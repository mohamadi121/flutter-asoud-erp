import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_traffic_correction.dart';

void main() {
  group('الگوی درخواست اصلاح تردد', () {
    test('ساختار معتبر، شناسه‌های پایدار و برچسب‌های فارسی دارد', () {
      final schema = hrTrafficCorrectionPreset();
      final fields = schemaFields(schema);

      expect(schema['title'], 'درخواست اصلاح تردد');
      expect(schema['kind'], 'Request');
      expect(schema['module'], 'HR');
      expect(fields.map((field) => field['key']).toSet().length, fields.length);
      expect(schemaProblems(schema), isEmpty);
      expect(
        fields.where((field) => field['required'] == true).map((field) => field['key']),
        containsAll(['correction_type', 'attendance_date', 'correction_reason']),
      );
      expect(
        fields.firstWhere((field) => field['key'] == 'correction_type')['options'],
        equals([
          {'id': 'missing_check_in', 'label': 'فراموشی ثبت ورود'},
          {'id': 'missing_check_out', 'label': 'فراموشی ثبت خروج'},
          {'id': 'correct_recorded_time', 'label': 'اصلاح ساعت ثبت‌شده'},
          {'id': 'other', 'label': 'سایر موارد'},
        ]),
      );
    });

    testWidgets('شرط‌ها و اعتبارسنجی فقط برای فیلدهای نمایان در پیش‌نمایش اجرا می‌شوند',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final schema = hrTrafficCorrectionPreset();
      final formKey = GlobalKey<FormState>();
      var values = <String, dynamic>{
        'correction_type': 'missing_check_in',
        'attendance_date': '2026-10-22',
        'correction_reason': 'ثبت ورود فراموش شد',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: StatefulBuilder(
                    builder: (context, setState) => FormFieldsView(
                      schema: schema,
                      values: values,
                      repository: FormRepository(_Client(), 'شرکت نمونه آسود'),
                      onChanged: (updated) => setState(() => values = updated),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ساعت ورود پیشنهادی *'), findsOneWidget);
      expect(find.text('ساعت خروج پیشنهادی'), findsNothing);
      expect(find.text('رکورد تردد'), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('انتخاب الزامی است.'), findsOneWidget);

      final inTime = schemaFields(schema)
          .firstWhere((field) => field['key'] == 'proposed_check_in_time');
      final record = schemaFields(schema)
          .firstWhere((field) => field['key'] == 'attendance_record_details');
      expect(formFlag(inTime, schema, values, 'required'), isTrue);
      expect(formFlag(record, schema, values, 'required'), isFalse);

      values = {
        'correction_type': 'correct_recorded_time',
        'attendance_date': '2026-10-22',
        'correction_reason': 'زمان ثبت‌شده نادرست است',
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: FormFieldsView(
                    schema: schema,
                    values: values,
                    repository: FormRepository(_Client(), 'شرکت نمونه آسود'),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ساعت ورود پیشنهادی'), findsNothing);
      expect(find.text('مشخصات رکورد تردد *'), findsOneWidget);
      expect(find.text('ساعت صحیح پیشنهادی *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('بلوک متقاضی و فرم در اندازه‌های RTL بدون خطا نمایش داده می‌شوند',
        (tester) async {
      final schema = hrTrafficCorrectionPreset();
      final fields = schemaFields(schema);
      final employee = fields.firstWhere((field) => field['key'] == 'applicant_employee');
      final department = fields.firstWhere((field) => field['key'] == 'applicant_department');
      final position = fields.firstWhere((field) => field['key'] == 'applicant_position');
      expect(employee['default_source'], 'employee');
      expect(department['default_source'], 'department');
      expect(position['default_source'], 'designation');
      expect([employee, department, position].any((field) => field.containsKey('default')), isFalse);

      for (final size in [const Size(320, 640), const Size(390, 844), const Size(430, 932)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: FormFieldsView(
                  schema: schema,
                  values: const {},
                  repository: FormRepository(_Client(), 'شرکت نمونه آسود'),
                  onChanged: (_) {},
                ),
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
  });
}

class _Client extends Fake implements FrappeApiClient {}
