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
    void Function(Map<String, dynamic>) changed) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
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
    expect(schema['short_title'], 'درخواست گواهی اشتغال');
    expect(keys.toSet().length, keys.length);
    expect(keys, containsAll(['applicant_name', 'recipient', 'purpose', 'purpose_details', 'certificate_language', 'include_compensation', 'delivery_method']));
    expect(keys.any((key) => '$key'.contains('office')), isFalse);
    expect(fields.firstWhere((field) => field['key'] == 'recipient')['required'], isTrue);
    expect(fields.firstWhere((field) => field['key'] == 'purpose')['label'], 'هدف از دریافت گواهی');
    expect(fields.firstWhere((field) => field['key'] == 'purpose')['options'], [
      {'id': 'bank', 'label': 'ارائه به بانک'},
      {'id': 'embassy', 'label': 'ارائه به سفارت'},
      {'id': 'organization', 'label': 'ارائه به سازمان یا شرکت'},
      {'id': 'other', 'label': 'سایر موارد'},
    ]);
  });

  testWidgets('renders at 360 by 800 with the conditional purpose detail hidden', (tester) async {
    final schema = employmentCertificatePreset();
    final values = <String, dynamic>{
      'recipient': 'بانک ملی',
      'purpose': 'bank',
      'certificate_language': 'persian',
      'include_compensation': 'no',
      'delivery_method': 'electronic',
    };
    await tester.pumpWidget(_preview(schema, values, (_) {}));
    await tester.pump();

    expect(find.text('شرح هدف'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(OverflowBar), findsNothing);
    expect((tester.state<FormState>(find.byType(Form)).validate()), isTrue);
    await tester.pump();
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
    await tester.pumpWidget(_preview(schema, values, (_) {}));
    await tester.pump();
    expect(find.text('شرح هدف *'), findsOneWidget);
    expect((tester.state<FormState>(find.byType(Form)).validate()), isFalse);
    await tester.pump();
    expect(formFlag(schemaFields(schema).firstWhere((field) => field['key'] == 'purpose_details'), schema, values, 'required'), isTrue);
  });
}
