import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime.dart';
import 'package:asoud_erp/features/form_builder/forms_page.dart';
import 'package:asoud_erp/features/form_builder/presets/hr_training.dart';

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

  testWidgets('پیش‌نمایش آموزش در ۳۶۰ بدون سرریز شرط‌ها و الزام‌ها را اعمال می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final schema = hrTrainingPreset();
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

    expect(find.text('دوره آموزشی *'), findsOneWidget);
    expect(find.text('عنوان آموزش پیشنهادی *'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('پیشنهاد آموزش جدید').last);
    await tester.pumpAndSettle();

    expect(find.text('دوره آموزشی *'), findsNothing);
    expect(find.text('عنوان آموزش پیشنهادی *'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pump();
    expect(find.text('تکمیل این فیلد الزامی است.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'کارگاه تحلیل داده');
    await tester.tap(find.text('آزمایش ثبت'));
    await tester.pump();
    expect(
      find.text('ساختار و مقادیر فرم با موفقیت در حالت آزمایشی اعتبارسنجی شدند. هیچ داده‌ای در سرور ثبت نگردید.'),
      findsOneWidget,
    );
  });
}

class _PreviewClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => false;
}
