import 'dart:convert';
import 'dart:io';

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
        'review_flow_notice': 'گردش بررسی و انجام عملیات',
        'final_warning': 'هشدار',
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

  test('طرح تجهیزات قرارداد مقدارهای خودکار و جدول‌های الزامی را دارد', () {
    final fields = _fields(hrEquipmentPreset());
    final applicant = {
      for (final field in fields.where((field) => '${field['key']}'.startsWith('applicant_')))
        '${field['key']}': field,
    };
    expect(applicant['applicant_employee']!['default_source'], 'employee');
    expect(applicant['applicant_department']!['default_source'], 'department');
    expect(applicant['applicant_position']!['default_source'], 'designation');
    for (final field in applicant.values) {
      expect(field['readonly'], true);
      expect(field.containsKey('default'), isFalse);
    }

    expect(
      fields.singleWhere((field) => field['key'] == 'equipment_request_type')['style'],
      'radio',
    );
    for (final key in ['requested_equipment', 'returnable_equipment']) {
      final table = fields.singleWhere((field) => field['key'] == key);
      expect(table['required'], true);
      expect(table['min_rows'], 1);
      final quantity = formMaps(table['columns']).singleWhere((column) => column['key'] == 'quantity');
      expect(quantity['type'], 'Integer');
      expect(quantity['min'], 1);
    }
    final returnReference = formMaps(
      fields.singleWhere((field) => field['key'] == 'returnable_equipment')['columns'],
    ).singleWhere((column) => column['key'] == 'equipment_reference');
    expect(returnReference['source'], 'Asset');
    expect(returnReference['unique'], isTrue);
    expect(returnReference.containsKey('system_source'), isFalse);

    final sections = formMaps(hrEquipmentPreset()['sections']);
    final schedule = sections.singleWhere((section) => section['id'] == 'schedule');
    expect(schedule['title'], 'زمان‌بندی پیشنهادی');
    expect(schedule['icon'], 'event');
    expect(schedule['color'], '#2E7D32');
    expect(schedule['background_color'], '#E5F7EF');
  });

  test('طرح تجهیزات برای اعتبارسنجی سرور ذخیره می‌شود', () {
    final output = File('/tmp/claude-1000/preset-hr_equipment.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(jsonEncode(hrEquipmentPreset()));
    expect(output.existsSync(), isTrue);
  });

  test('قواعد حالت دریافت و عودت مقدارهای پنهان را حذف می‌کنند', () {
    final schema = hrEquipmentPreset();
    final receive = evaluatedValues(schema, {
      'equipment_request_type': 'receive_equipment',
      'requested_equipment': [],
      'needed_date': '1405-01-20',
      'suggested_return_date': '1405-01-21',
    });
    expect(receive.containsKey('requested_equipment'), isTrue);
    expect(receive.containsKey('returnable_equipment'), isFalse);
    expect(receive.containsKey('needed_date'), isTrue);
    expect(receive.containsKey('suggested_return_date'), isFalse);

    final returned = evaluatedValues(schema, {
      'equipment_request_type': 'return_equipment',
      'requested_equipment': [],
      'returnable_equipment': [],
      'needed_date': '1405-01-20',
      'suggested_return_date': '1405-01-21',
    });
    expect(returned.containsKey('requested_equipment'), isFalse);
    expect(returned.containsKey('returnable_equipment'), isTrue);
    expect(returned.containsKey('needed_date'), isFalse);
    expect(returned.containsKey('suggested_return_date'), isTrue);
  });

  test('فیلدهای الزامی پنهان اعتبارسنجی را در حالت عودت مسدود نمی‌کنند', () {
    final schema = hrEquipmentPreset();
    final values = evaluatedValues(schema, {
      'equipment_request_type': 'return_equipment',
      'returnable_equipment': [
        {'equipment_reference': 'ITEM-1', 'quantity': 1, 'reported_condition': 'healthy'},
      ],
    });
    expect(values.containsKey('receive_reason'), isFalse);
    expect(values.containsKey('requested_equipment'), isFalse);
    expect(values['returnable_equipment'], isNotEmpty);
  });

  test('کارت‌های گردش و هشدار نهایی متن خنثی و دقیق دارند', () {
    final fields = [
      for (final s in hrEquipmentPreset()['sections'] as List)
        for (final f in (s as Map)['fields'] as List) f as Map,
    ];
    expect(
        fields.firstWhere((f) => f['key'] == 'review_flow_notice')['default'],
        'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.');
    expect(
        fields.firstWhere((f) => f['key'] == 'final_warning')['default'],
        'ثبت درخواست به‌معنای ثبت ورود یا خروج کالا، تحویل قطعی تجهیز، عودت واقعی یا تسویه مسئولیت اموال نیست.');
    expect(fields.firstWhere((f) => f['key'] == 'receive_reason')['default'],
        'work_need');
    expect(fields.any((f) => f.containsKey('placeholder')), isFalse);
  });

  testWidgets(
      'پیش‌نمایش RTL در اندازه‌های موبایل شرط‌ها و اجبار فیلد قابل مشاهده را اعمال می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
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

    await tester.ensureVisible(find.text('عودت تجهیزات').first);
    await tester.tap(find.text('عودت تجهیزات').first);
    await tester.pumpAndSettle();

    expect(find.text('تجهیزات مورد درخواست *'), findsNothing);
    expect(find.text('تجهیزات قابل عودت *'), findsOneWidget);
    expect(find.text('شرح دلیل *'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final size in [const Size(390, 844), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
