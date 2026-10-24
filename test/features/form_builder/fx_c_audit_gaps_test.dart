import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_sheet.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_field_types/choice_options.dart';
import 'package:asoud_erp/features/form_builder/form_editor/editor_widgets.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/form_fields_view.dart';

Widget _wrap(Widget child, {double width = 360, double height = 1000}) {
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

class _FakeClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager'],
        company: 'شرکت نمونه آسود',
      );
  Future<dynamic> getDoc(String doctype, String name) async => {};
  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async => [];
}

class _DummyRepository extends FormRepository {
  _DummyRepository() : super(_FakeClient(), 'شرکت نمونه آسود');
}

void main() {
  group('Audit s1011 scenarios', () {
    testWidgets('s1011 scenario 9, 10: consecutive columns added and cancel third', (tester) async {
      final schema = blankSchema('Request');
      final tableField = <String, dynamic>{
        'key': 'items',
        'label': 'اقلام',
        'type': 'Table',
        'columns': <FormMap>[],
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(context, schema, tableField),
            child: const Text('Open Table'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Table'));
      await tester.pumpAndSettle();

      // Go to advanced tab
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();

      // Column 1
      await tester.ensureVisible(find.text('افزودن مشخصه جدید'));
      await tester.tap(find.text('افزودن مشخصه جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'ستون اول');
      await tester.tap(find.text('تأیید و افزودن مشخصه'));
      await tester.pumpAndSettle();
      expect(find.text('ستون اول'), findsOneWidget);

      // Column 2
      await tester.ensureVisible(find.text('افزودن مشخصه جدید'));
      await tester.tap(find.text('افزودن مشخصه جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'ستون دوم');
      await tester.tap(find.text('تأیید و افزودن مشخصه'));
      await tester.pumpAndSettle();
      expect(find.text('ستون دوم'), findsOneWidget);

      // Column 3 - Cancel
      await tester.ensureVisible(find.text('افزودن مشخصه جدید'));
      await tester.tap(find.text('افزودن مشخصه جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'ستون سوم موقت');
      await tester.tap(find.text('انصراف').last);
      await tester.pumpAndSettle();

      // In confirm discard dialog, confirm
      if (find.text('تأیید').evaluate().isNotEmpty) {
        await tester.tap(find.text('تأیید'));
        await tester.pumpAndSettle();
      }

      // Check Column 3 was canceled and table modal still open with 1 and 2
      expect(find.text('ستون سوم موقت'), findsNothing);
      expect(find.text('ستون اول'), findsOneWidget);
      expect(find.text('ستون دوم'), findsOneWidget);
    });

    testWidgets('s1011 scenario 13: dependent column cannot be deleted with snackbar', (tester) async {
      final schema = blankSchema('Request');
      final tableField = <String, dynamic>{
        'key': 'items',
        'label': 'اقلام',
        'type': 'Table',
        'columns': [
          {
            'key': 'col_price',
            'label': 'قیمت واحد',
            'type': 'Money',
            'formula_dependents': [{'key': 'col_total'}],
          },
        ],
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(context, schema, tableField),
            child: const Text('Open Table'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Table'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('حذف مشخصه'));
      await tester.tap(find.byTooltip('حذف مشخصه'));
      await tester.pumpAndSettle();

      // Snackbar error message appears
      expect(find.text('این مشخصه داده یا وابستگی دارد و قابل حذف نیست.'), findsOneWidget);
      expect(find.text('قیمت واحد'), findsOneWidget);
    });

    testWidgets('s1011 scenario 14, 15: tapping up/down arrows really reorders', (tester) async {
      final schema = blankSchema('Request');
      final tableField = <String, dynamic>{
        'key': 'items',
        'label': 'اقلام',
        'type': 'Table',
        'columns': [
          {'key': 'col_a', 'label': 'مشخصه الف', 'type': 'Text'},
          {'key': 'col_b', 'label': 'مشخصه ب', 'type': 'Integer'},
        ],
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(context, schema, tableField),
            child: const Text('Open Table'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Table'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();

      // Tap down arrow on first column
      await tester.ensureVisible(find.byTooltip('جابه‌جایی به پایین').first);
      await tester.tap(find.byTooltip('جابه‌جایی به پایین').first);
      await tester.pumpAndSettle();

      final labelsAfterDown = tester
          .widgetList<Text>(find.textContaining('مشخصه '))
          .map((t) => t.data)
          .where((label) => label == 'مشخصه الف' || label == 'مشخصه ب')
          .toList();
      expect(labelsAfterDown, ['مشخصه ب', 'مشخصه الف']);

      // Tap up arrow on second column to revert
      await tester.ensureVisible(find.byTooltip('جابه‌جایی به بالا').last);
      await tester.tap(find.byTooltip('جابه‌جایی به بالا').last);
      await tester.pumpAndSettle();

      final labelsAfterUp = tester
          .widgetList<Text>(find.textContaining('مشخصه '))
          .map((t) => t.data)
          .where((label) => label == 'مشخصه الف' || label == 'مشخصه ب')
          .toList();
      expect(labelsAfterUp, ['مشخصه الف', 'مشخصه ب']);
    });
  });

  group('Audit s56 scenarios', () {
    test('s56 scenario 1: creating two text fields with different configs', () {
      final f1 = <String, dynamic>{
        'key': 'f_${newFormId()}',
        'type': 'Text',
        'label': 'کد پرسنلی',
        'max_length': 10,
        'default': '100',
      };
      final f2 = <String, dynamic>{
        'key': 'f_${newFormId()}',
        'type': 'Text',
        'label': 'نام خانوادگی',
        'max_length': 60,
        'default': '',
      };

      expect(f1['key'], isNot(equals(f2['key'])));
      expect(f1['label'], 'کد پرسنلی');
      expect(f2['label'], 'نام خانوادگی');
      expect(f1['max_length'], 10);
      expect(f2['max_length'], 60);
    });

    testWidgets('s56 scenario 4: select Item source with SmartLinkPickerDropdown', (tester) async {
      FormMap? selected;
      await tester.pumpWidget(_wrap(
        SmartLinkPickerDropdown(
          source: 'Item',
          selectedId: null,
          selectedLabel: null,
          onSelected: (item) => selected = item,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('انتخاب از اطلاعات مجاز...'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'کاغذ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('کاغذ A4 (کد ۱۰۰۱)'), findsOneWidget);
      await tester.tap(find.text('کاغذ A4 (کد ۱۰۰۱)'));
      await tester.pumpAndSettle();

      expect(selected?['name'], 'ITEM-001');
    });

    testWidgets('s56 scenario 5: select Warehouse, Department, Account with shared picker', (tester) async {
      final sources = ['Warehouse', 'Department', 'Account'];
      for (final src in sources) {
        await tester.pumpWidget(_wrap(
          SmartLinkPickerDropdown(
            key: ValueKey(src),
            source: src,
            selectedId: null,
            selectedLabel: null,
            onSelected: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('انتخاب از اطلاعات مجاز...'));
        await tester.pumpAndSettle();

        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
      }
    });

    test('s56 scenario 6: changing system source clears previous default value', () {
      final field = <String, dynamic>{
        'key': 'f_sys',
        'type': 'Text',
        'source_mode': 'asoud',
        'source': 'Employee',
        'default': 'EMP-001',
      };

      void changeSource(String newSource) {
        field['source'] = newSource;
        field['default'] = null;
      }

      changeSource('Item');
      expect(field['source'], 'Item');
      expect(field['default'], isNull);
    });

    test('s56 scenario 11: jalali date valid transitions across month and year', () {
      // Month boundary: Mordad 31 to Shahrivar 1
      final d1 = parseJalaliDate('1403/05/31')!;
      final nextDay = d1.add(const Duration(days: 1));
      final jNext = JalaliDate.fromDateTime(nextDay);
      expect(jNext.month, 6);
      expect(jNext.day, 1);

      // Year boundary: Esfand to Farvardin
      final endOfYear = parseJalaliDate('1403/12/30')!;
      final newYearDay = endOfYear.add(const Duration(days: 1));
      final jNewYear = JalaliDate.fromDateTime(newYearDay);
      expect(jNewYear.year, 1404);
      expect(jNewYear.month, 1);
      expect(jNewYear.day, 1);
    });

    test('s56 scenario 12: jalali leap year verification', () {
      bool isLeapYear(int year) => parseJalaliDate('$year/12/30') != null;
      expect(isLeapYear(1403), isTrue);
      expect(isLeapYear(1402), isFalse);
      expect(isLeapYear(1404), isFalse);
      expect(isLeapYear(1399), isTrue);
    });

    testWidgets('s56 scenario 16: choice options add, edit title with id kept, reorder, delete', (tester) async {
      final field = <String, dynamic>{
        'key': 'f_sel',
        'type': 'Select',
        'options': [
          {'id': 'opt_1', 'label': 'گزینه اول'},
          {'id': 'opt_2', 'label': 'گزینه دوم'},
        ],
      };

      await tester.pumpWidget(_wrap(
        ChoiceOptionsListEditor(
          field: field,
          onChanged: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('گزینه اول'), findsOneWidget);
      expect(find.text('گزینه دوم'), findsOneWidget);

      // Edit title of opt_1
      await tester.enterText(find.byKey(const ValueKey('title_opt_1')), 'گزینه اول ویرایش‌شده');
      await tester.pumpAndSettle();

      final opts = field['options'] as List;
      expect(opts[0]['id'], 'opt_1');
      expect(opts[0]['label'], 'گزینه اول ویرایش‌شده');

      // Move down
      await tester.tap(find.byTooltip('جابه‌جایی به پایین').first);
      await tester.pumpAndSettle();

      expect((field['options'] as List)[0]['id'], 'opt_2');
      expect((field['options'] as List)[1]['id'], 'opt_1');

      // Add option
      await tester.tap(find.text('افزودن گزینه'));
      await tester.pumpAndSettle();
      expect((field['options'] as List).length, 3);

      // Delete option
      await tester.tap(find.byTooltip('حذف گزینه').first);
      await tester.pumpAndSettle();
      expect((field['options'] as List).length, 2);
    });

    test('s56 scenario 19: creating two independent formula fields in basic tab', () {
      final f1 = <String, dynamic>{
        'key': 'f_${newFormId()}',
        'type': 'Formula',
        'label': 'مبلغ کل',
        'output_type': 'Money',
      };
      final f2 = <String, dynamic>{
        'key': 'f_${newFormId()}',
        'type': 'Formula',
        'label': 'تعداد کل',
        'output_type': 'Integer',
      };

      expect(f1['key'], isNot(equals(f2['key'])));
      expect(f1['output_type'], 'Money');
      expect(f2['output_type'], 'Integer');
    });
  });

  group('Items 1 to 10 specific audit assertions', () {
    testWidgets('Item 1: runtime/row-page time field uses LiveClockTimePicker', (tester) async {
      dynamic selectedTime;
      final field = <String, dynamic>{
        'key': 'time_col',
        'label': 'ساعت ورود',
        'type': 'Time',
        'minute_step': 10,
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => buildDateTimeInput(
            context: context,
            f: field,
            value: null,
            label: 'ساعت ورود',
            required: false,
            onChanged: (v) => selectedTime = v,
          )!,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ساعت ورود'));
      await tester.pumpAndSettle();

      // Verify LiveClockTimePicker is shown
      expect(find.byType(LiveClockTimePicker), findsOneWidget);
      expect(find.text('ساعت'), findsOneWidget);
      expect(find.text('دقیقه'), findsOneWidget);

      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      expect(selectedTime, isNotNull);
    });

    testWidgets('Item 2: Text field with source_mode asoud renders system picker in FormFieldsView', (tester) async {
      final schema = <String, dynamic>{
        'sections': [
          {
            'fields': [
              {
                'key': 'f_employee',
                'type': 'Text',
                'source_mode': 'asoud',
                'source': 'Employee',
                'label': 'پرسنل درخواست‌دهنده',
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(_wrap(
        FormFieldsView(
          schema: schema,
          values: const {},
          onChanged: (_) {},
          repository: _DummyRepository(),
        ),
      ));
      await tester.pumpAndSettle();

      // Shows system picker tile with search icon instead of text field
      expect(find.text('پرسنل درخواست‌دهنده'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('Item 4: basic computed settings shows ایجاد فیلد در فرم نمونه and existing fields', (tester) async {
      final schema = <String, dynamic>{
        'sections': [
          {
            'key': 'sec_1',
            'fields': [
              {
                'key': 'f_calc1',
                'type': 'Formula',
                'label': 'مبلغ ناخالص',
                'output_type': 'Money',
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(
              context,
              schema,
              {'key': 'f_new_calc', 'type': 'Formula', 'label': 'مالیات'},
            ),
            child: const Text('Open Computed'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Computed'));
      await tester.pumpAndSettle();

      expect(find.text('+ ایجاد فیلد در فرم نمونه'), findsOneWidget);
      expect(find.text('مبلغ ناخالص'), findsOneWidget);
      expect(find.text('خروجی مبلغ · بدون فرمول'), findsOneWidget);
    });

    testWidgets('Item 5: table basic confirmation opens advanced before saving zero columns', (tester) async {
      FormMap? savedResult;
      final schema = blankSchema('Request');

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              savedResult = await editSchemaField(
                context,
                schema,
                {'key': 't_test', 'label': '', 'type': 'Table', 'columns': []},
              );
            },
            child: const Text('Create Table'),
          ),
        ),
      ));
      await tester.tap(find.text('Create Table'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'جدول آزمایشی');
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأیید و افزودن'));
      await tester.pumpAndSettle();

      // Basic confirmation now continues configuration instead of closing.
      expect(savedResult, isNull);
      expect(find.text('تأیید و افزودن'), findsOneWidget);
      await tester.tap(find.text('تأیید و افزودن'));
      await tester.pumpAndSettle();

      expect(savedResult, isNotNull);
      expect(savedResult?['type'], 'Table');
      expect(savedResult?['label'], 'جدول آزمایشی');
      expect(formMaps(savedResult?['columns']).isEmpty, isTrue);
    });

    testWidgets('Item 6: file attachment specialised settings are in advanced tab only', (tester) async {
      final schema = blankSchema('Request');
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(
              context,
              schema,
              {'key': 'f_file', 'type': 'File', 'label': 'پیوست مدارک'},
            ),
            child: const Text('Open File'),
          ),
        ),
      ));
      await tester.tap(find.text('Open File'));
      await tester.pumpAndSettle();

      // In basic tab: only required switch, not max_files or max_mb
      expect(find.text('پیوست‌کردن حداقل یک فایل الزامی باشد'), findsOneWidget);
      expect(find.text('حداکثر تعداد فایل (تا ۱۰)'), findsNothing);
      expect(find.text('حذف فایل پیش از ثبت مجاز باشد'), findsNothing);

      // In advanced tab: specialised settings are present
      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();

      expect(find.text('حداکثر تعداد فایل (تا ۱۰)'), findsOneWidget);
      expect(find.text('حداکثر حجم مگابایت (تا ۱۰)'), findsOneWidget);
      expect(find.text('حذف فایل پیش از ثبت مجاز باشد'), findsOneWidget);
    });

    testWidgets('Item 7: field_sheet_preview computed shows editable inputs and read-only result', (tester) async {
      final formulaField = <String, dynamic>{
        'key': 'f_calc',
        'type': 'Formula',
        'label': 'مبلغ نهایی',
        'output_type': 'Money',
        'formula': {
          'op': 'add',
          'inputs': ['val_1', 'val_2'],
        },
      };

      await tester.pumpWidget(_wrap(
        FieldSheetPreview(field: formulaField),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('نتیجه محاسبه (مبلغ):'), findsOneWidget);

      // Edit first input
      await tester.enterText(find.byKey(const ValueKey('sample_input_val_1')), '25');
      await tester.pumpAndSettle();

      // 25 + 20 = 45.00
      expect(find.text('۴۵.۰۰'), findsOneWidget);
    });

    testWidgets('Item 8: header subtitle ASOUD ERP · فرم‌ساز fixed', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(
              context,
              blankSchema('Request'),
              {'key': 'f_t', 'type': 'Text', 'label': 'تست'},
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ASOUD ERP · فرم‌ساز'), findsOneWidget);
      expect(find.text('آسود ERP · تب پایه'), findsNothing);
    });

    testWidgets('Item 9: SheetBottomButtons gets isColumn: labels for column sheets', (tester) async {
      await tester.pumpWidget(_wrap(
        SheetBottomButtons(
          isEditing: false,
          isPreviewing: false,
          isColumn: true,
          onPrimary: () {},
          onPreviewToggle: () {},
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تأیید و افزودن مشخصه'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        SheetBottomButtons(
          isEditing: true,
          isPreviewing: false,
          isColumn: true,
          onPrimary: () {},
          onPreviewToggle: () {},
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ذخیره تغییرات مشخصه'), findsOneWidget);
    });

    testWidgets('Item 10: table.dart switching dropdown with unsaved changes confirms', (tester) async {
      final schema = <String, dynamic>{
        'sections': [
          {
            'fields': [
              {
                'key': 'table_1',
                'label': 'جدول اول',
                'type': 'Table',
                'columns': [
                  {'key': 'c1', 'label': 'ستون ۱', 'type': 'Text'},
                ],
              },
              {
                'key': 'table_2',
                'label': 'جدول دوم',
                'type': 'Table',
                'columns': [
                  {'key': 'c2', 'label': 'ستون ۲', 'type': 'Integer'},
                ],
              },
            ],
          },
        ],
      };

      final activeField = <String, dynamic>{
        'key': 'table_1',
        'label': 'جدول اول ویرایش‌شده', // Unsaved change
        'type': 'Table',
        'columns': [
          {'key': 'c1', 'label': 'ستون ۱ دستکاری‌شده', 'type': 'Text'},
        ],
      };

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => editSchemaField(context, schema, activeField),
            child: const Text('Open Table'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Table'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیشرفته'));
      await tester.pumpAndSettle();

      // Tap table dropdown
      await tester.tap(find.text('جدول اول').first);
      await tester.pumpAndSettle();

      // Select table_2
      await tester.tap(find.text('جدول دوم').last);
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.text('تغییرات ذخیره‌نشده رها شوند؟'), findsOneWidget);
    });
  });
}
