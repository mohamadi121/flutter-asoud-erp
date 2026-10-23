import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_training.dart';

class _TrainingHarness extends StatefulWidget {
  const _TrainingHarness({required this.schema, required this.values});

  final FormMap schema;
  final FormMap values;

  @override
  State<_TrainingHarness> createState() => _TrainingHarnessState();
}

class _TrainingHarnessState extends State<_TrainingHarness> {
  final key = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: key,
                child: FormFieldsView(
                  schema: widget.schema,
                  values: widget.values,
                  repository: FormRepository(_PreviewClient(), 'شرکت آزمون'),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
}

void main() {
  test('الگوی درخواست آموزش شناسه‌ها، برچسب‌ها و قوانین پایدار دارد', () {
    final schema = hrTrainingPreset();
    final fields = schemaFields(schema);

    expect(schema['title'], 'درخواست آموزش کارکنان');
    expect(schema['module'], 'HR');
    expect(schema['kind'], 'Request');
    expect(schema['icon'], 'school');
    expect(schema['color'], '#1876D2');
    expect(
      formPresets('Request')
          .where((preset) => preset['title'] == 'درخواست آموزش کارکنان'),
      hasLength(1),
    );
    expect(fields.map((field) => field['key']).toSet().length, fields.length);
    expect(schemaProblems(schema), isEmpty);
    expect(fields.where((field) => field['required'] == true).map((field) => field['key']),
        containsAll(<String>['request_type', 'training_goal']));
    expect(fields.map((field) => field['key']), containsAll(<String>[
      'applicant_employee', 'applicant_department', 'applicant_position',
    ]));
    expect(fields.firstWhere((field) => field['key'] == 'applicant_employee')['default_source'], 'employee');
    expect(fields.firstWhere((field) => field['key'] == 'applicant_department')['default_source'], 'department');
    expect(fields.firstWhere((field) => field['key'] == 'applicant_position')['default_source'], 'designation');
    expect(fields.where((field) => field.containsKey('system_source')), isEmpty);
    expect(fields.where((field) => field['key'] == 'training_course').single['type'], 'Text');
    expect(fields.where((field) => field['key'] == 'training_course').single['help'], contains('فهرست دوره‌های آموزشی در دسترس نیست.'));
    for (final key in ['request_type', 'delivery_method', 'cost_status']) {
      expect(fields.firstWhere((field) => field['key'] == key)['style'], 'radio');
    }
    final endDate = fields.firstWhere((field) => field['key'] == 'proposed_end_date');
    expect(endDate['after_or_equal'], 'proposed_start_date');
    expect(endDate['after_or_equal_message'], 'تاریخ پایان نباید قبل از تاریخ شروع باشد.');
    expect(fields.firstWhere((field) => field['key'] == 'proposed_training_title')['label'],
        'عنوان آموزش پیشنهادی');
    expect(fields.firstWhere((field) => field['key'] == 'estimated_cost')['min'], 0.01);

    for (final rule in schema['rules'] as List) {
      expect(fields.map((field) => field['key']), contains(rule['target']));
      for (final condition in rule['conditions'] as List) {
        expect(fields.map((field) => field['key']), contains(condition['field']));
      }
    }
  });

  testWidgets('پیش‌نمایش آموزش در اندازه‌های RTL شرط‌ها و الزام‌ها را اعمال می‌کند',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    final schema = hrTrainingPreset();
    for (final size in [const Size(320, 640), const Size(390, 844), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        home: FormPreviewPage(
          schema: schema,
          repository: FormRepository(_PreviewClient(), 'شرکت آزمون'),
          initialValues: const {
            'request_type': 'existing_course',
            'training_goal': 'job_skill',
            'cost_status': 'unknown',
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('دریافت خودکار'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);

    expect(find.text('دوره آموزشی *'), findsOneWidget);
    expect(find.text('عنوان آموزش پیشنهادی *'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('پیشنهاد آموزش جدید').last);
    await tester.pumpAndSettle();

    expect(find.text('دوره آموزشی *'), findsNothing);
    expect(find.text('عنوان آموزش پیشنهادی *'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pump();
    expect(find.text('تکمیل این فیلد الزامی است.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'عنوان آموزش پیشنهادی *'), 'کارگاه تحلیل داده');
    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pump();
    expect(
      find.text('ساختار و مقادیر فرم با موفقیت در حالت آزمایشی اعتبارسنجی شدند. هیچ داده‌ای در سرور ثبت نگردید.'),
      findsOneWidget,
    );
  });

  test('قانون‌های آموزش مقدارهای پنهان را از مقادیر نهایی حذف می‌کنند', () {
    final schema = hrTrainingPreset();
    expect(evaluatedValues(schema, {
      'request_type': 'new_training',
      'training_course': 'دوره قدیمی',
      'training_goal': 'job_skill',
      'training_goal_details': 'شرح قدیمی',
      'cost_status': 'unknown',
      'estimated_cost': '120000',
    }), isNot(containsPair('training_course', 'دوره قدیمی')));
    expect(evaluatedValues(schema, {
      'request_type': 'existing_course',
      'training_goal': 'job_skill',
      'training_goal_details': 'شرح قدیمی',
      'cost_status': 'no_cost',
      'estimated_cost': '120000',
    }), isNot(containsPair('training_goal_details', 'شرح قدیمی')));
    expect(evaluatedValues(schema, {
      'request_type': 'existing_course',
      'training_goal': 'job_skill',
      'cost_status': 'no_cost',
      'estimated_cost': '120000',
    }), isNot(containsPair('estimated_cost', '120000')));
  });

  testWidgets('تاریخ پایان پیش از تاریخ شروع با پیام فارسی رد می‌شود', (tester) async {
    await tester.pumpWidget(_TrainingHarness(
      schema: hrTrainingPreset(),
      values: {
        'request_type': 'new_training',
        'proposed_training_title': 'کارگاه تحلیل داده',
        'training_goal': 'job_skill',
        'cost_status': 'unknown',
        'proposed_start_date': '2026-10-24',
        'proposed_end_date': '2026-10-23',
      },
    ));
    await tester.pump();

    final state = tester.state<_TrainingHarnessState>(find.byType(_TrainingHarness));
    expect(state.key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('تاریخ پایان نباید قبل از تاریخ شروع باشد.'), findsOneWidget);
  });
}

class _PreviewClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}
