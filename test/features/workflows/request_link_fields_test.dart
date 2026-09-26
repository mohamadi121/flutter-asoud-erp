import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/request_types/presentation/pages/request_field_editor_page.dart';
import 'package:asoud_erp/features/request_types/presentation/widgets/field_type_sheet.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_link_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements GenericRequestRepository {}

const _fields = [
  {
    'key': 'needs',
    'label': 'نیازها',
    'type': 'Multi Choice',
    'options': ['لپ‌تاپ', 'مانیتور'],
    'default_value': 'مانیتور',
  },
  {'key': 'owner', 'label': 'تحویل‌گیرنده', 'type': 'User', 'required': true},
  {'key': 'unit', 'label': 'واحد درخواست‌کننده', 'type': 'Department'},
  {'key': 'items', 'label': 'اقلام', 'type': 'Item Table', 'required': true},
  {
    'key': 'note',
    'label': 'یادداشت',
    'type': 'Short Text',
    'default_value': 'پیش‌فرض',
  },
];

_Repository _repository() {
  final repo = _Repository();
  when(() => repo.options()).thenAnswer((_) async => [
        {
          'name': 'equipment',
          'workflow_title': 'درخواست تجهیزات',
          'fields': _fields
        },
      ]);
  when(() => repo.fieldOptions('User', txt: any(named: 'txt')))
      .thenAnswer((_) async => [
            {'value': 'ali@example.com', 'label': 'علی رضایی'}
          ]);
  when(() => repo.fieldOptions('Department', txt: any(named: 'txt')))
      .thenAnswer((_) async => [
            {'value': 'IT - T', 'label': 'فناوری اطلاعات'}
          ]);
  when(() => repo.fieldOptions('Item', txt: any(named: 'txt')))
      .thenAnswer((_) async => [
            {'value': 'ITM-1', 'label': 'کاغذ A4', 'stock_uom': 'Nos'}
          ]);
  when(() => repo.fieldOptions('UOM', itemCode: 'ITM-1'))
      .thenAnswer((_) async => [
            {'value': 'Nos', 'label': 'Nos'},
            {'value': 'Box', 'label': 'Box'},
          ]);
  return repo;
}

Future<void> _openForm(WidgetTester tester, _Repository repo) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light, home: GenericRequestPage(repository: repo)));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ExpansionTile).first);
  await tester.pumpAndSettle();
  tester
      .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first)
      .onChanged!('equipment');
  await tester.pumpAndSettle();
  tester
      .widgetList<AsoudFormField>(
          find.byType(AsoudFormField, skipOffstage: false))
      .first
      .controller
      .text = 'درخواست تجهیزات واحد';
  await tester.tap(find.text('اطلاعات درخواست'));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, Finder field, String option) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new field types collect ERPNext values and builder defaults',
      (tester) async {
    final repo = _repository();
    Map<String, dynamic>? saved;
    when(() => repo.create(any(), any())).thenAnswer((call) async {
      saved = Map.from(call.positionalArguments.first as Map);
      return null;
    });
    await _openForm(tester, repo);

    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'مانیتور'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(FilterChip, 'لپ‌تاپ'));
    await tester.pumpAndSettle();
    await _pick(tester, find.widgetWithText(InputDecorator, 'تحویل‌گیرنده'),
        'علی رضایی');
    expect(find.text('علی رضایی'), findsOneWidget);
    await _pick(
        tester,
        find.widgetWithText(InputDecorator, 'واحد درخواست‌کننده'),
        'فناوری اطلاعات');
    await _pick(tester, find.text('افزودن کالا'), 'کاغذ A4');
    await tester.enterText(find.widgetWithText(TextFormField, 'مقدار'), '2');
    await tester.tap(find.text('Nos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Box').last);
    await tester.pumpAndSettle();

    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(saved!['values'], {
      'needs': ['لپ‌تاپ', 'مانیتور'],
      'owner': 'ali@example.com',
      'unit': 'IT - T',
      'items': [
        {'item_code': 'ITM-1', 'qty': 2, 'uom': 'Box'}
      ],
      'note': 'پیش‌فرض',
    });
  });

  testWidgets('required user and item table block submission', (tester) async {
    final repo = _repository();
    await _openForm(tester, repo);
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('این فیلد الزامی است.'), findsOneWidget);
    expect(find.text('حداقل یک ردیف کالا لازم است.'), findsOneWidget);
    verifyNever(() => repo.create(any(), any()));
  });

  test('stored values are shown readably', () {
    expect(formatRequestValue(null), '—');
    expect(formatRequestValue(const []), '—');
    expect(formatRequestValue(true), 'بله');
    expect(formatRequestValue(const ['الف', 'ب']), 'الف\nب');
    expect(
        formatRequestValue(const [
          {'item_code': 'ITM-1', 'item_name': 'کاغذ', 'qty': 2.0, 'uom': 'Box'},
          {'item_code': 'ITM-2', 'qty': 1.5, 'uom': 'Nos'},
        ]),
        'کاغذ × 2 Box\nITM-2 × 1.5 Nos');
  });

  testWidgets('builder offers the new types with the right settings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showFieldTypeSheet(context),
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final label in ['چندانتخابی', 'کاربر', 'واحد سازمانی', 'جدول اقلام']) {
      expect(
          tester.widget<ListTile>(find.widgetWithText(ListTile, label)).enabled,
          isTrue);
    }
    expect(find.text('به‌زودی'), findsNothing);

    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: const RequestFieldEditorPage(type: 'Multi Choice')));
    expect(find.text('گزینه‌ها'), findsOneWidget);
    expect(find.text('مقدار پیش‌فرض (اختیاری)'), findsOneWidget);
    for (final type in ['User', 'Department', 'Item Table']) {
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light, home: RequestFieldEditorPage(type: type)));
      expect(find.text('مقدار پیش‌فرض (اختیاری)'), findsNothing, reason: type);
      expect(find.text('گزینه‌ها'), findsNothing, reason: type);
    }
  });
}
