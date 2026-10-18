import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_widgets.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';

Widget _wrapTestWidget(Widget child, {double width = 360, double height = 800}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('basic field cards count and labels', (tester) async {
    expect(basicFieldCards.length, 11);
    expect(basicFieldCards[0].label, 'متن کوتاه');
    expect(basicFieldCards[1].label, 'متن بلند');
    expect(basicFieldCards[2].label, 'عدد');
    expect(basicFieldCards[3].label, 'مبلغ');
    expect(basicFieldCards[4].label, 'تاریخ');
    expect(basicFieldCards[5].label, 'ساعت');
    expect(basicFieldCards[6].label, 'فهرست انتخابی');
    expect(basicFieldCards[7].label, 'چک‌لیست');
    expect(basicFieldCards[8].label, 'فیلد محاسباتی');
    expect(basicFieldCards[9].label, 'جدول تکرارشونده');
    expect(basicFieldCards[10].label, 'پیوست فایل');
  });

  testWidgets('FieldTypeGrid renders in 360 and 320 px without overflow', (tester) async {
    for (final width in [360.0, 320.0]) {
      String selected = 'Text';
      await tester.pumpWidget(_wrapTestWidget(
        StatefulBuilder(
          builder: (context, setState) => FieldTypeGrid(
            selectedType: selected,
            onSelectType: (t) => setState(() => selected = t),
          ),
        ),
        width: width,
      ));
      await tester.pumpAndSettle();

      expect(find.text('متن کوتاه'), findsOneWidget);
      expect(find.text('جدول تکرارشونده'), findsOneWidget);
      expect(find.text('پیوست فایل'), findsOneWidget);

      // Select table card
      await tester.tap(find.text('جدول تکرارشونده'));
      await tester.pumpAndSettle();
      expect(selected, 'Table');
    }
  });

  testWidgets('LiveClockTimePicker confirms selected time', (tester) async {
    String? confirmed;
    var cancelled = false;

    await tester.pumpWidget(_wrapTestWidget(
      LiveClockTimePicker(
        initialTime: '14:30',
        minuteStep: 15,
        onConfirm: (t) => confirmed = t,
        onCancel: () => cancelled = true,
      ),
      width: 360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ساعت'), findsOneWidget);
    expect(find.text('دقیقه'), findsOneWidget);
    expect(find.text('تأیید'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);

    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    expect(confirmed, '14:30');
    expect(cancelled, false);
  });

  testWidgets('SmartLinkPicker dropdown expands and selects items', (tester) async {
    FormMap? selected;

    await tester.pumpWidget(_wrapTestWidget(
      SmartLinkPickerDropdown(
        source: 'Employee',
        selectedId: null,
        selectedLabel: null,
        onSelected: (item) => selected = item,
      ),
      width: 360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب از اطلاعات مجاز...'), findsOneWidget);

    // Tap to open
    await tester.tap(find.text('انتخاب از اطلاعات مجاز...'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // Wait for mock results
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('علی محمدی (مدیر مالی - ۱۰۱)'), findsOneWidget);

    await tester.tap(find.text('علی محمدی (مدیر مالی - ۱۰۱)'));
    await tester.pumpAndSettle();

    expect(selected?['name'], 'EMP-001');
  });

  testWidgets('SheetBottomButtons renders buttons with correct labels and styles', (tester) async {
    var primaryPressed = false;
    var previewPressed = false;
    var cancelPressed = false;

    await tester.pumpWidget(_wrapTestWidget(
      SheetBottomButtons(
        isEditing: false,
        isPreviewing: false,
        onPrimary: () => primaryPressed = true,
        onPreviewToggle: () => previewPressed = true,
        onCancel: () => cancelPressed = true,
      ),
      width: 360,
    ));
    await tester.pumpAndSettle();

    expect(find.text('تأیید و افزودن'), findsOneWidget);
    expect(find.text('پیش‌نمایش'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);

    await tester.tap(find.text('تأیید و افزودن'));
    await tester.tap(find.text('پیش‌نمایش'));
    await tester.tap(find.text('انصراف'));

    expect(primaryPressed, true);
    expect(previewPressed, true);
    expect(cancelPressed, true);
  });

  testWidgets('SheetBottomButtons in edit mode shows ذخیره تغییرات', (tester) async {
    await tester.pumpWidget(_wrapTestWidget(
      SheetBottomButtons(
        isEditing: true,
        isPreviewing: true,
        onPrimary: () {},
        onPreviewToggle: () {},
        onCancel: () {},
      ),
      width: 320,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ذخیره تغییرات'), findsOneWidget);
    expect(find.text('بازگشت به تنظیمات'), findsOneWidget);
  });

  testWidgets('editSchemaField opens sheet, edits title, validates and saves', (tester) async {
    FormMap? result;
    final schema = blankSchema('Request');

    await tester.pumpWidget(_wrapTestWidget(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await editSchemaField(
              context,
              schema,
              {'key': 'f_1', 'label': '', 'type': 'Text'},
            );
          },
          child: const Text('Open'),
        ),
      ),
      width: 360,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('افزودن فیلد'), findsOneWidget);
    expect(find.text('کتابخانه فیلدها'), findsOneWidget);

    // Tap save without label -> error
    await tester.tap(find.text('تأیید و افزودن'));
    await tester.pumpAndSettle();
    expect(find.text('عنوان فیلد الزامی است'), findsOneWidget);

    // Enter label
    await tester.enterText(find.byType(TextFormField).first, 'نام درخواست‌کننده');
    await tester.pumpAndSettle();

    // Tap save
    await tester.tap(find.text('تأیید و افزودن'));
    await tester.pumpAndSettle();

    expect(result != null, true);
    expect(result!['label'], 'نام درخواست‌کننده');
    expect(result!['type'], 'Text');
  });

  testWidgets('FieldSheetPreview renders table and file attachments', (tester) async {
    for (final width in [360.0, 320.0]) {
      await tester.pumpWidget(_wrapTestWidget(
        SingleChildScrollView(
          child: Column(
            children: [
              FieldSheetPreview(
                field: {
                  'key': 'f_tbl',
                  'label': 'اقلام درخواست',
                  'type': 'Table',
                  'orientation': 'horizontal',
                  'columns': [
                    {'key': 'c_1', 'label': 'کد کالا'},
                    {'key': 'c_2', 'label': 'تعداد'},
                  ],
                },
              ),
              FieldSheetPreview(
                field: {
                  'key': 'f_file',
                  'label': 'فایل پیوست',
                  'type': 'File',
                  'required': true,
                },
              ),
            ],
          ),
        ),
        width: width,
      ));
      await tester.pumpAndSettle();

      expect(find.text('اقلام درخواست'), findsOneWidget);
      expect(find.text('فایل پیوست'), findsOneWidget);
      expect(find.text('جهت جدول: افقی (افزودن ردیف)'), findsOneWidget);
      expect(find.text('کد کالا'), findsOneWidget);
      expect(find.text('برای پیوست فایل ضربه بزنید یا فایل را بکشید'), findsOneWidget);
    }
  });
}
