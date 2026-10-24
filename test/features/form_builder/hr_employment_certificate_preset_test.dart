import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_employment_certificate.dart';

class _Client extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}

class _Repository extends FormRepository {
  _Repository() : super(_Client(), 'شرکت نمونه آسود');
}

Widget _preview(Map<String, dynamic> schema, Map<String, dynamic> values,
    void Function(Map<String, dynamic>) changed, Size size) {
  return MaterialApp(
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
                onChanged: changed,
                repository: _Repository(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('schema has stable Persian fields, valid rules, and no office field', () {
    final schema = employmentCertificatePreset();
    final fields = schemaFields(schema);
    final keys = fields.map((field) => field['key']).toList();

    expect(schemaProblems(schema), isEmpty);
    expect(schema['title'], 'درخواست گواهی اشتغال به کار');
    expect(schema.containsKey('short_title'), isFalse);
    expect(keys.toSet().length, keys.length);
    expect(keys, containsAll(['applicant_employee', 'recipient', 'purpose', 'purpose_details', 'certificate_language', 'include_compensation', 'delivery_method']));
    expect(keys.any((key) => '$key'.contains('office')), isFalse);
    final employee = fields.firstWhere((field) => field['key'] == 'applicant_employee');
    final department = fields.firstWhere((field) => field['key'] == 'applicant_department');
    final position = fields.firstWhere((field) => field['key'] == 'applicant_position');
    expect(employee, containsPair('type', 'Link'));
    expect(employee, containsPair('source', 'Employee'));
    expect(employee, containsPair('default_source', 'employee'));
    expect(employee.containsKey('default'), isFalse);
    expect(department, containsPair('type', 'Link'));
    expect(department, containsPair('source', 'Department'));
    expect(department, containsPair('default_source', 'department'));
    expect(position, containsPair('default_source', 'designation'));
    expect(position.containsKey('default'), isFalse);
    expect({for (final field in fields) field['key']: field['label']}, containsPair('applicant_department', 'واحد سازمانی'));
    expect({for (final field in fields) field['key']: field['label']}, containsPair('applicant_position', 'سمت سازمانی'));
    expect(fields.firstWhere((field) => field['key'] == 'recipient')['required'], isTrue);
    expect(fields.firstWhere((field) => field['key'] == 'purpose')['label'], 'هدف از دریافت گواهی');
    expect({for (final field in fields) field['key']: field['label']}, containsPair('purpose_details', 'شرح هدف'));
    expect({for (final field in fields) field['key']: field['label']}, containsPair('certificate_language', 'زبان گواهی'));
    expect({for (final field in fields) field['key']: field['label']}, containsPair('include_compensation', 'درج حقوق و مزایا در گواهی'));
    expect({for (final field in fields) field['key']: field['label']}, containsPair('delivery_method', 'روش دریافت پیشنهادی'));
    expect({for (final field in fields) field['key']: field['label']}, containsPair('additional_notes', 'توضیحات تکمیلی'));
    expect(fields.firstWhere((field) => field['key'] == 'purpose')['options'], [
      {'id': 'bank', 'label': 'ارائه به بانک'},
      {'id': 'embassy', 'label': 'ارائه به سفارت'},
      {'id': 'organization', 'label': 'ارائه به سازمان یا شرکت'},
      {'id': 'other', 'label': 'سایر موارد'},
    ]);
    expect(fields.firstWhere((field) => field['key'] == 'delivery_method')['style'], 'radio');
  });

  test('داده ساختار گواهی برای اعتبارسنجی سرور ذخیره می‌شود', () {
    Directory('/tmp/claude-1000').createSync(recursive: true);
    File('/tmp/claude-1000/preset-employment-certificate.json')
        .writeAsStringSync(jsonEncode(employmentCertificatePreset()));
  });

  testWidgets('renders at required RTL mobile sizes with the conditional purpose detail hidden', (tester) async {
    final schema = employmentCertificatePreset();
    final values = <String, dynamic>{
      'recipient': 'بانک ملی',
      'purpose': 'bank',
      'certificate_language': 'persian',
      'include_compensation': 'no',
      'delivery_method': 'electronic',
    };
    for (final size in const [Size(320, 640), Size(390, 844), Size(430, 932)]) {
      await tester.pumpWidget(_preview(schema, values, (_) {}, size));
      await tester.pump();

      expect(find.text('شرح هدف'), findsNothing);
      expect(find.text('دریافت خودکار'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      expect(find.byType(OverflowBar), findsNothing);
      expect((tester.state<FormState>(find.byType(Form)).validate()), isTrue);
      await tester.pump();
    }
  });

  testWidgets('shows and requires purpose detail only for other purpose', (tester) async {
    final schema = employmentCertificatePreset();
    final values = <String, dynamic>{
      'recipient': 'بانک ملی',
      'purpose': 'other',
      'certificate_language': 'persian',
      'include_compensation': 'no',
      'delivery_method': 'electronic',
    };
    await tester.pumpWidget(_preview(schema, values, (_) {}, const Size(390, 844)));
    await tester.pump();
    expect(find.text('شرح هدف *'), findsOneWidget);
    expect((tester.state<FormState>(find.byType(Form)).validate()), isFalse);
    await tester.pump();
    expect(formFlag(schemaFields(schema).firstWhere((field) => field['key'] == 'purpose_details'), schema, values, 'required'), isTrue);
    expect(evaluatedValues(schema, {...values, 'purpose_details': 'مانده'}).containsKey('purpose_details'), isTrue);
    expect(evaluatedValues(schema, {...values, 'purpose': 'bank', 'purpose_details': 'مانده'}).containsKey('purpose_details'), isFalse);
  });

  test('زبان و درج حقوق رادیویی‌اند و کارت‌های گردش خنثی‌اند', () {
    final schema = employmentCertificatePreset();
    final fields = schemaFields(schema);
    Map f(String k) => fields.firstWhere((x) => x['key'] == k);
    expect(f('certificate_language')['style'], 'radio');
    expect(f('include_compensation')['style'], 'radio');
    expect(f('delivery_method')['style'], 'radio');
    expect(f('workflow_notice')['default'], 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.');
    expect(f('preview_notice')['default'],
        'این صفحه پیش‌نمایش درخواست است، نه متن گواهی صادرشده. صدور سند واقعی به داده معتبر، مجوز و قالب سند نیاز دارد.');
    expect(schema.containsKey('short_title'), isFalse);
  });
}
