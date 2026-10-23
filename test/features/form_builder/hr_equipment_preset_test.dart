import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_equipment.dart';

class _PresetClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'employee@asoud.local',
        fullName: 'کارمند آزمایشی',
        roles: ['Employee'],
        company: 'شرکت نمونه آسود',
      );
}

List<FormMap> _fields(FormMap schema) => [
      for (final section in formMaps(schema['sections']))
        ...formMaps(section['fields']),
    ];

void main() {
  final repository = FormRepository(_PresetClient(), 'شرکت نمونه آسود');

  test('طرح تحویل یا عودت تجهیزات شناسه‌ها، برچسب‌ها و قواعد پایدار دارد', () {
    final schema = hrEquipmentPreset();
    final fields = _fields(schema);
    final keys = fields.map((field) => field['key']).toList();

    expect(schema['title'], 'درخواست تحویل یا عودت تجهیزات');
    expect(schema['module'], 'HR');
    expect(schema['icon'], 'box');
    expect(schema['color'], '#1876D2');
    expect(keys.toSet(), hasLength(keys.length));
    expect(
      {for (final field in fields) '${field['key']}': field['label']},
      {
        'applicant_employee': 'نام و نام خانوادگی',
        'applicant_department': 'واحد سازمانی',
        'applicant_position': 'سمت سازمانی',
        'equipment_request_type': 'نوع درخواست',
        'requested_equipment': 'تجهیزات مورد درخواست',
        'requested_equipment_total': 'جمع تعداد تجهیزات',
        'returnable_equipment': 'تجهیزات قابل عودت',
        'returnable_equipment_total': 'جمع تعداد تجهیزات انتخاب‌شده',
        'receive_reason': 'دلیل درخواست',
        'other_receive_reason': 'شرح دلیل',
        'needed_date': 'تاریخ موردنیاز',
        'suggested_return_date': 'تاریخ پیشنهادی عودت',
        'general_notes': 'توضیحات تکمیلی',
      },
    );
    expect(
        fields
            .where((field) => field['required'] == true)
            .map((field) => field['key']),
        containsAll([
          'equipment_request_type',
          'requested_equipment',
          'returnable_equipment',
          'receive_reason'
        ]));
    expect(
        fields.singleWhere(
            (field) => field['key'] == 'requested_equipment')['label'],
        'تجهیزات مورد درخواست');
    expect(
        fields.singleWhere(
            (field) => field['key'] == 'returnable_equipment')['label'],
        'تجهیزات قابل عودت');
    expect(
        fields.singleWhere(
            (field) => field['key'] == 'requested_equipment_total')['label'],
        'جمع تعداد تجهیزات');
    expect(
        fields.singleWhere(
            (field) => field['key'] == 'returnable_equipment_total')['label'],
        'جمع تعداد تجهیزات انتخاب‌شده');
    for (final tableKey in ['requested_equipment', 'returnable_equipment']) {
      final columns = formMaps(
        fields.singleWhere((field) => field['key'] == tableKey)['columns'],
      );
      final columnKeys = columns.map((column) => column['key']).toList();
      expect(columnKeys.toSet(), hasLength(columnKeys.length));
    }
    expect(
        fields.singleWhere(
            (field) => field['key'] == 'equipment_request_type')['options'],
        [
          {'id': 'receive_equipment', 'label': 'دریافت تجهیزات'},
          {'id': 'return_equipment', 'label': 'عودت تجهیزات'},
        ]);

    final targets = schema['rules'] as List;
    for (final rule in targets.cast<FormMap>()) {
      expect(keys, contains(rule['target']));
      for (final condition in formMaps(rule['conditions'])) {
        expect(keys, contains(condition['field']));
      }
    }
  });

  test('طرح تحویل یا عودت تجهیزات از اعتبارسنجی طرح فرم عبور می‌کند', () {
    expect(schemaProblems(hrEquipmentPreset()), isEmpty);
  });

  testWidgets(
      'پیش‌نمایش اجرا در ۳۶۰×۸۰۰ شرط‌ها و اجبار فیلد قابل مشاهده را اعمال می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final formKey = GlobalKey<FormState>();
    final schema = hrEquipmentPreset();
    var values = <String, dynamic>{
      'equipment_request_type': 'receive_equipment',
      'receive_reason': 'other',
    };

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: formKey,
                child: FormFieldsView(
                  schema: schema,
                  values: values,
                  repository: repository,
                  onChanged: (next) => setState(() => values = next),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('تجهیزات مورد درخواست *'), findsOneWidget);
    expect(find.text('تجهیزات قابل عودت *'), findsNothing);
    expect(find.text('شرح دلیل *'), findsOneWidget);

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('تکمیل این فیلد الزامی است.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('عودت تجهیزات').last);
    await tester.pumpAndSettle();

    expect(find.text('تجهیزات مورد درخواست *'), findsNothing);
    expect(find.text('تجهیزات قابل عودت *'), findsOneWidget);
    expect(find.text('شرح دلیل *'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
