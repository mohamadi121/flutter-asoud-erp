import 'dart:convert';
import 'dart:typed_data';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_attachments.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_field_widgets.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

final _png = base64Decode(
    (requestData('get_attachment') as Map)['content_base64'] as String);

class _Loader {
  final calls = <Map<String, Object?>>[];
  final masters = <String, List<Map<String, dynamic>>>{
    'Leave Type': [
      {'value': 'Casual Leave', 'label': 'سالانه', 'category': 'annual'},
      {'value': 'Sick Leave', 'label': 'استعلاجی', 'category': 'sick'},
    ],
    'Item': [
      {
        'value': 'ICU-MON-01',
        'label': 'مانیتور ICU',
        'item_code': 'ICU-MON-01',
        'stock_uom': 'Nos'
      },
      {
        'value': 'CABLE-5M',
        'label': 'کابل ۵ متری',
        'item_code': 'CABLE-5M',
        'stock_uom': 'Meter'
      },
    ],
    'UOM': [
      {'value': 'Nos', 'label': 'Nos'},
      {'value': 'Box', 'label': 'Box'},
    ],
    'Delivery Location': [
      {'value': 'branch:Tehran', 'label': 'تهران', 'kind': 'branch'},
      {
        'value': 'warehouse:Stores - WP',
        'label': 'انبار مرکزی',
        'kind': 'warehouse'
      },
    ],
  };

  Future<List<Map<String, dynamic>>> call(String fieldType,
      {String txt = '', String? itemCode, String? scope}) async {
    calls.add(
        {'type': fieldType, 'txt': txt, 'itemCode': itemCode, 'scope': scope});
    return [
      for (final row in masters[fieldType] ?? const <Map<String, dynamic>>[])
        if (txt.isEmpty || '${row['label']}'.contains(txt)) row
    ];
  }
}

RequestFormController _form(String template, _Loader loader,
        {RequestFilePicker? picker, bool marks = false}) =>
    RequestFormController.fromType(
        requestOptionFixtures()
            .firstWhere((row) => row['template_key'] == template),
        loadOptions: loader.call,
        filePicker: picker,
        showRequiredMarks: marks);

Future<void> _pump(WidgetTester tester, RequestFormController form,
    {List<String>? keys, bool enabled = true, double width = 390}) async {
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (final field in form.fields)
              if (keys == null || keys.contains(field.key))
                RequestFieldWidget(
                    controller: form, field: field, enabled: enabled),
          ]),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Time opens a 24-hour picker and keeps HH:MM', (tester) async {
    final form = _form('leave', _Loader());
    form.setValue('request_kind', 'Hourly');
    // The system time picker needs a wider test surface than a phone for the
    // test font; on a device it fits.
    await _pump(tester, form, keys: ['start_time', 'end_time'], width: 800);
    expect(find.byType(AsoudFormTimeField), findsNWidgets(2));
    form.setValue('start_time', '09:30');
    await tester.pumpAndSettle();
    expect(find.text('۰۹:۳۰'), findsOneWidget, reason: 'Persian digits');
    expect(form.value('start_time'), '09:30', reason: 'canonical Latin digits');

    await tester.tap(find.byTooltip('انتخاب ساعت').last);
    await tester.pumpAndSettle();
    expect(find.text('ساعت پایان'), findsWidgets);
    // 24-hour: no AM/PM switch.
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();
    expect(form.value('end_time'), '08:00');
    expect(find.text('۰۸:۰۰'), findsOneWidget);

    form.setValue('end_time', null);
    await tester.pumpAndSettle();
    expect(form.value('end_time'), isNull);
  });

  testWidgets('segmented Choice shows option_labels and swaps the blocks',
      (tester) async {
    final form = _form('leave', _Loader());
    await _pump(tester, form);
    expect(find.byType(AsoudSegmentedControl<String>), findsOneWidget);
    expect(find.text('روزانه'), findsOneWidget);
    expect(find.text('ساعتی'), findsOneWidget);
    expect(find.text('Daily'), findsNothing, reason: 'the label, not the key');
    expect(find.text('تاریخ شروع'), findsOneWidget);
    expect(find.text('تاریخ پایان'), findsOneWidget);
    expect(find.text('ساعت شروع'), findsNothing);
    expect(find.text('تاریخ مرخصی'), findsNothing);

    await tester.tap(find.text('ساعتی'));
    await tester.pumpAndSettle();
    expect(form.value('request_kind'), 'Hourly');
    expect(find.text('تاریخ شروع'), findsNothing);
    expect(find.text('ساعت شروع'), findsOneWidget);
    expect(find.text('ساعت پایان'), findsOneWidget);
    expect(find.text('تاریخ مرخصی'), findsOneWidget);
    final control = tester.widget<AsoudSegmentedControl<String>>(
        find.byType(AsoudSegmentedControl<String>));
    expect(control.value, 'Hourly');
    expect(control.options.map((option) => option.value), ['Daily', 'Hourly']);
  });

  testWidgets('chips and dropdown Choice use the stored key', (tester) async {
    final form = _form('supply', _Loader());
    await _pump(tester, form, keys: ['supply_method', 'priority']);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(find.text('از انبار'), findsOneWidget);
    await tester.tap(find.text('از انبار'));
    await tester.pumpAndSettle();
    expect(form.value('supply_method'), 'Warehouse');
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'از انبار'))
            .selected,
        isTrue);
    await tester.tap(find.text('خرید'));
    await tester.pumpAndSettle();
    expect(form.value('supply_method'), 'Purchase');

    final dropdown = WorkflowFormFieldDefinition.fromMap({
      'key': 'kind',
      'label': 'نوع',
      'type': 'Choice',
      'options': ['a', 'b'],
      'option_labels': {'a': 'الف', 'b': 'ب'},
    });
    final other =
        RequestFormController(fields: [dropdown], loadOptions: _Loader().call);
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Scaffold(
            body: RequestFieldWidget(controller: other, field: dropdown))));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ب').last);
    await tester.pumpAndSettle();
    expect(other.value('kind'), 'b');
  });

  testWidgets('System Select searches the master and keeps the record name',
      (tester) async {
    final loader = _Loader();
    final form = _form('leave', loader);
    await _pump(tester, form, keys: ['leave_type', 'location']);
    expect(find.text('نوع مرخصی'), findsOneWidget);
    await tester.tap(find.widgetWithText(InputDecorator, 'نوع مرخصی'));
    await tester.pumpAndSettle();
    expect(loader.calls.last['type'], 'Leave Type');
    expect(find.text('سالانه'), findsOneWidget);
    expect(find.text('استعلاجی'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'استع');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(loader.calls.last['txt'], 'استع');
    expect(find.text('سالانه'), findsNothing);
    await tester.tap(find.text('استعلاجی'));
    await tester.pumpAndSettle();
    expect(form.value('leave_type'), 'Sick Leave');
    expect(form.labelFor('leave_type'), 'استعلاجی');
    expect(find.text('استعلاجی'), findsOneWidget, reason: 'label is shown');
    expect(find.text('Sick Leave'), findsNothing);
    // Default of the branch field is shown with its label.
    expect(form.value('location'), 'Tehran');
    expect(find.text('تهران'), findsOneWidget);
  });

  testWidgets('delivery locations are grouped by kind', (tester) async {
    final form = _form('supply', _Loader());
    await _pump(tester, form, keys: ['delivery_location']);
    await tester.tap(find.widgetWithText(InputDecorator, 'محل تحویل'));
    await tester.pumpAndSettle();
    expect(find.text('انبار'), findsOneWidget);
    expect(find.text('شعبه'), findsOneWidget);
    await tester.tap(find.text('انبار مرکزی'));
    await tester.pumpAndSettle();
    expect(form.value('delivery_location'), 'warehouse:Stores - WP');
  });

  testWidgets('Auto fields are read-only and never sent', (tester) async {
    final form = _form('leave', _Loader());
    await _pump(tester, form,
        keys: ['request_number', 'request_date', 'duration']);
    expect(find.text('شماره درخواست'), findsOneWidget);
    expect(find.text('پس از ثبت تولید می‌شود'), findsOneWidget);
    expect(find.text(formatJalaliIso(DateTime.now().toIso8601String())),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    form.setAutoText('duration', '۳ روز');
    await tester.pumpAndSettle();
    expect(find.text('۳ روز'), findsOneWidget);
    expect(form.payloadValues().keys,
        isNot(anyOf(contains('duration'), contains('request_number'))));
  });

  testWidgets('a non-editable field is locked', (tester) async {
    final form = _form('purchase', _Loader());
    await _pump(tester, form, keys: ['requester']);
    expect(find.text('سارا محمدی'), findsOneWidget);
    await tester.tap(find.widgetWithText(InputDecorator, 'درخواست‌کننده'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('dates show Jalali and required marks are optional',
      (tester) async {
    final form = _form('purchase', _Loader(), marks: true);
    form.setValue('needed_date', '2026-10-20');
    await _pump(tester, form, keys: ['needed_date', 'reason', 'project']);
    expect(find.text(formatJalaliIso('2026-10-20')), findsOneWidget);
    expect(find.text('تاریخ مورد نیاز *'), findsOneWidget);
    expect(find.text('دلیل درخواست *'), findsOneWidget);
    expect(find.text('پروژه'), findsOneWidget);

    form.validate();
    await tester.pumpAndSettle();
    expect(find.text('این فیلد الزامی است.'), findsOneWidget); // the reason
    form.setValue('needed_date', '2020-01-01');
    form.validate();
    await tester.pumpAndSettle();
    expect(find.text('تاریخ نمی‌تواند در گذشته باشد.'), findsOneWidget);
  });

  testWidgets('Long Text shows the max_length counter and stores the text',
      (tester) async {
    final form = _form('purchase', _Loader());
    await _pump(tester, form, keys: ['reason']);
    await tester.enterText(
        find.byKey(const ValueKey('SYS-PURCHASE-WP:reason')), 'نیاز بخش');
    await tester.pumpAndSettle();
    expect(form.value('reason'), 'نیاز بخش');
    expect(find.text('۸/۲۰۰۰'), findsOneWidget);
  });

  group('item table', () {
    testWidgets('adds an item with its code and unit, note and row file',
        (tester) async {
      final loader = _Loader();
      final picked = <String>[];
      final form = _form('purchase', loader, picker: (limits) async {
        picked.add('picked');
        return [(filename: 'm.png', bytes: Uint8List.fromList(_png))];
      });
      await _pump(tester, form, keys: ['items']);
      expect(find.text('افزودن کالا'), findsOneWidget);
      await tester.tap(find.text('افزودن کالا'));
      await tester.pumpAndSettle();
      expect(loader.calls.last['type'], 'Item');
      expect(loader.calls.last['scope'], 'purchase',
          reason: 'item_scope of the template');
      await tester.tap(find.text('مانیتور ICU'));
      await tester.pumpAndSettle();

      expect(find.text('مانیتور ICU'), findsOneWidget);
      expect(find.text('ICU-MON-01'), findsOneWidget, reason: 'item code');
      expect(
          form.value('items'),
          [
            {'item_code': 'ICU-MON-01', 'qty': 1, 'uom': 'Nos'}
          ],
          reason: 'the unit is filled from the item stock unit');
      expect(
          loader.calls
              .any((c) => c['type'] == 'UOM' && c['itemCode'] == 'ICU-MON-01'),
          isTrue);

      await tester.enterText(find.widgetWithText(TextFormField, 'مقدار'), '۳');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'توضیحات قلم'), 'سریع');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'شرح / مشخصات'), 'مدل XS');
      await tester.pumpAndSettle();
      final row = (form.payloadValues()['items'] as List).single as Map;
      expect(row['qty'], 3);
      expect(row['note'], 'سریع');
      expect(row['description'], 'مدل XS');

      await tester.tap(find.text('Nos').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Box').last);
      await tester.pumpAndSettle();
      expect(((form.value('items') as List).single as Map)['uom'], 'Box');

      await tester.tap(find.text('افزودن فایل'));
      await tester.pumpAndSettle();
      expect(picked, hasLength(1));
      expect(find.byKey(const ValueKey('row-thumb:0')), findsOneWidget,
          reason: 'thumbnail of the picked image');
      expect(find.text('m.png'), findsOneWidget);
      final payload = form.payloadValues();
      final file = ((payload['items'] as List).single as Map)['attachment'];
      expect(file, startsWith('attachment:att-'));
      final uploads = form.attachmentUploads();
      expect(uploads.single['ref'], '$file'.replaceFirst('attachment:', ''));
      expect(form.generalDrafts, isEmpty, reason: 'a row file is not general');

      // Removing the row file drops the upload.
      await tester.tap(find.byTooltip('حذف فایل'));
      await tester.pumpAndSettle();
      expect(form.attachmentUploads(), isEmpty);
      expect(find.text('افزودن فایل'), findsOneWidget);

      await tester.tap(find.byTooltip('حذف ردیف'));
      await tester.pumpAndSettle();
      expect(form.value('items'), isEmpty);
    });

    testWidgets('supply rows have no note; services are offered (scope all)',
        (tester) async {
      final loader = _Loader();
      final form = _form('supply', loader);
      await _pump(tester, form, keys: ['items']);
      await tester.tap(find.text('افزودن کالا'));
      await tester.pumpAndSettle();
      expect(loader.calls.last['scope'], 'all');
      await tester.tap(find.text('کابل ۵ متری'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'توضیحات قلم'), findsNothing);
      expect(
          find.widgetWithText(TextFormField, 'شرح / مشخصات'), findsOneWidget);
      expect(find.text('افزودن فایل'), findsOneWidget);
    });

    testWidgets('the error of the controller is shown under the table',
        (tester) async {
      final form = _form('purchase', _Loader());
      await _pump(tester, form, keys: ['items']);
      form.validate();
      await tester.pumpAndSettle();
      expect(find.text('حداقل یک ردیف کالا لازم است.'), findsOneWidget);
    });

    testWidgets('a file that breaks the limits is refused with a message',
        (tester) async {
      final form = _form('purchase', _Loader(),
          picker: (limits) async => [
                (filename: 'virus.exe', bytes: Uint8List(4)),
              ]);
      await _pump(tester, form, keys: ['items']);
      await tester.tap(find.text('افزودن کالا'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مانیتور ICU'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('افزودن فایل'));
      await tester.pumpAndSettle();
      expect(find.textContaining('فرمت فایل مجاز نیست'), findsOneWidget);
      expect(form.drafts, isEmpty);
    });
  });

  testWidgets('the attachments picker shows the limits and adds general files',
      (tester) async {
    final form = _form('leave', _Loader(),
        picker: (limits) async => [
              (filename: 'a.pdf', bytes: Uint8List(2048)),
              (filename: 'b.xlsx', bytes: Uint8List(10)),
            ]);
    final messages = <String>[];
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: RequestAttachmentsPicker(
                    controller: form, onMessage: messages.add)))));
    expect(find.text('فایل یا فایل‌ها را انتخاب کنید'), findsOneWidget);
    expect(find.textContaining('JPG، JPEG، PNG، PDF، DOCX'), findsOneWidget);
    expect(find.textContaining('۱۰ مگابایت'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('request-attachments-dropzone')));
    await tester.pumpAndSettle();
    expect(form.generalDrafts.map((d) => d.filename), ['a.pdf']);
    expect(messages.single, contains('فرمت فایل مجاز نیست'));
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('۲ کیلوبایت'), findsOneWidget);
    await tester.tap(find.byTooltip('حذف فایل'));
    await tester.pumpAndSettle();
    expect(form.generalDrafts, isEmpty);
  });

  testWidgets('a field that is disabled while saving cannot be edited',
      (tester) async {
    final form = _form('purchase', _Loader());
    await _pump(tester, form, keys: ['reason'], enabled: false);
    final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('SYS-PURCHASE-WP:reason')));
    expect(field.enabled, isFalse);
  });

  testWidgets('the whole purchase form renders at 320 without overflow',
      (tester) async {
    final form = _form('purchase', _Loader());
    await tester.binding.setSurfaceSize(const Size(320, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              for (final field in form.fields)
                RequestFieldWidget(controller: form, field: field),
              RequestAttachmentsPicker(controller: form),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AsoudIconBox), findsWidgets);
  });

  testWidgets(
      'an empty searchable field draws only its label, not a second placeholder',
      (tester) async {
    final form = _form('purchase', _Loader());
    await _pump(tester, form, keys: ['cost_center', 'project']);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب کنید'), findsNothing);
    for (final label in ['مرکز هزینه', 'پروژه']) {
      final field = find.widgetWithText(InputDecorator, label);
      expect(field, findsOneWidget);
      // The label is the placeholder: it is painted once and nothing else is
      // painted on top of it.
      expect(find.descendant(of: field, matching: find.text(label)),
          findsOneWidget);
      final texts = tester
          .widgetList<Text>(
              find.descendant(of: field, matching: find.byType(Text)))
          .map((text) => text.data)
          .where((data) => data != null && data.isNotEmpty)
          .toList();
      expect(texts, [label]);
    }
    // Once a value is chosen the label floats and the value shows.
    form.setValue('project', 'PRJ-1', label: 'توسعه بخش ICU');
    await tester.pumpAndSettle();
    expect(find.text('توسعه بخش ICU'), findsOneWidget);
    expect(find.text('پروژه'), findsOneWidget);
  });

  testWidgets('item rows of template tables keep is_stock_item in memory only',
      (tester) async {
    final loader = _Loader();
    loader.masters['Item'] = [
      {
        'value': 'SVC-1',
        'label': 'خدمت نصب',
        'item_code': 'SVC-1',
        'stock_uom': 'Nos',
        'is_stock_item': 0
      },
    ];
    final form = _form('supply', loader);
    await _pump(tester, form, keys: ['items']);
    await tester.tap(find.text('افزودن کالا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خدمت نصب'));
    await tester.pumpAndSettle();
    final row = (form.value('items') as List).single as Map;
    expect(row['is_stock_item'], 0,
        reason: 'a form can check ITEM_NOT_STOCKABLE');
    expect(row['item_code'], 'SVC-1');
    expect((form.payloadValues()['items'] as List).single,
        {'item_code': 'SVC-1', 'qty': 1, 'uom': 'Nos'},
        reason: 'it is never sent');
  });
}
