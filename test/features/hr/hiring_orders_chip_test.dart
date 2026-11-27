import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/core/widgets/template_text.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hiring_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements HiringOrderRepository {}

// Real stored sample: the builder's own default template body (article 1).
const _defaultBody =
    'به موجب این حکم، [نام و نام خانوادگی پرسنل] با کد پرسنلی [کد پرسنلی] و مشخصات ثبت‌شده در پرونده منابع انسانی، مشمول مفاد این حکم می‌گردد.';

Map<String, dynamic> _published(String body) => {
      'revision': 1,
      'articles': [
        {'id': 'employee_details', 'title': 'مشخصات پرسنل', 'body': body},
      ],
      'payroll_rows': [
        {'id': 'base_salary', 'title': 'حقوق پایه', 'period': 'monthly', 'field_ref': 'base'},
      ],
    };

Widget _widget(_Repository repository, {double width = 390}) => MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: child!,
        ),
      ),
      home: HiringOrdersPage(
        company: 'شرکت تست',
        repository: repository,
        capabilities: Capabilities.full,
      ),
    );

Future<void> _openEditor(tester, _Repository repository, String body) async {
  when(() => repository.listOrders(
        company: 'شرکت تست',
        search: any(named: 'search'),
        status: any(named: 'status'),
      )).thenAnswer((_) async => []);
  when(() => repository.getTemplate(company: 'شرکت تست'))
      .thenAnswer((_) async => _published(body));
  when(() => repository.people(company: 'شرکت تست'))
      .thenAnswer((_) async => []);
  when(() => repository.payrollCatalog(company: 'شرکت تست'))
      .thenAnswer((_) async => []);

  await tester.pumpWidget(_widget(repository));
  await tester.pumpAndSettle();
  await tester.tap(find.text('قالب حکم استخدام'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ماده ۱: مشخصات پرسنل'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ویرایش'));
  await tester.pumpAndSettle();
}

TemplateTextController _bodyController(tester) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'متن ماده'))
        .controller! as TemplateTextController;

int _markerIndex(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) >= 0xe000) return i;
  }
  return -1;
}

void main() {
  late _Repository repository;
  setUp(() => repository = _Repository());

  testWidgets('known token shows a blue Persian chip while source is unchanged',
      (tester) async {
    const body = 'به موجب این حکم، {{employee_name}} با کد [کد پرسنلی] مشمول می‌گردد.';
    await _openEditor(tester, repository, body);
    expect(find.text('نام و نام خانوادگی پرسنل'), findsOneWidget);
    expect(_bodyController(tester).source, body);
  });

  testWidgets('inserting a field at the cursor in the middle of Persian text',
      (tester) async {
    const body = 'متن قبل و متن بعد';
    await _openEditor(tester, repository, body);
    final field = find.widgetWithText(TextFormField, 'متن ماده');
    await tester.showKeyboard(field);
    final controller = _bodyController(tester);
    controller.selection =
        TextSelection.collapsed(offset: 'متن قبل '.length);
    await tester.pump();
    await tester.tap(find.text('درج فیلد در متن ماده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[کد پرسنلی]'));
    await tester.pumpAndSettle();
    expect(controller.source, 'متن قبل [کد پرسنلی]و متن بعد');
  });

  testWidgets('deleting the chip leaves the surrounding text intact',
      (tester) async {
    const body = 'قبل {{employee_name}} بعد';
    await _openEditor(tester, repository, body);
    final field = find.widgetWithText(TextFormField, 'متن ماده');
    await tester.showKeyboard(field);
    final controller = _bodyController(tester);
    final idx = _markerIndex(controller.text);
    expect(idx, isNonNegative);
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: controller.text.replaceRange(idx, idx + 1, ''),
      selection: TextSelection.collapsed(offset: idx),
    ));
    await tester.pump();
    expect(controller.source, 'قبل  بعد');
  });

  testWidgets('undo restores the text after inserting a chip', (tester) async {
    const body = 'به موجب این حکم، ';
    await _openEditor(tester, repository, body);
    final field = find.widgetWithText(TextFormField, 'متن ماده');
    await tester.showKeyboard(field);
    final controller = _bodyController(tester);
    const offset = 0;
    controller.selection = TextSelection.collapsed(offset: offset);
    await tester.pump();
    controller.insertToken('{{employee_name}}');
    await tester.pump(const Duration(milliseconds: 600));
    final inserted = controller.value;
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: inserted.text.replaceRange(offset, offset + 1, ''),
      selection: TextSelection.collapsed(offset: offset),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.source, body);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.value.text, inserted.text);
  });

  testWidgets('unknown token is kept verbatim and shown as unknown',
      (tester) async {
    const body = 'متن با {{legacy.unknown_key}} در قالب';
    await _openEditor(tester, repository, body);
    expect(find.text('فیلد ناشناخته'), findsOneWidget);
    expect(_bodyController(tester).source, body);
  });

  testWidgets('default template body is saved byte-for-byte when unchanged',
      (tester) async {
    await _openEditor(tester, repository, _defaultBody);
    expect(_bodyController(tester).source, _defaultBody);
  });

  testWidgets('new article form inserts a field at the cursor', (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => _published(_defaultBody));
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => []);
    when(() => repository.payrollCatalog(company: 'شرکت تست'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_widget(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قالب حکم استخدام'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('افزودن ماده جدید'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextFormField, 'متن ماده جدید');
    await tester.enterText(field, 'متن');
    await tester.showKeyboard(field);
    final controller = tester.widget<TextFormField>(field)
        .controller! as TemplateTextController;
    controller.selection = TextSelection.collapsed(offset: 3);
    await tester.pump();
    await tester.tap(find.text('درج فیلد در ماده جدید'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[کد پرسنلی]'));
    await tester.pumpAndSettle();
    expect(controller.source, 'متن[کد پرسنلی]');
  });

  testWidgets('builder renders at 320 px without overflow', (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => _published(_defaultBody));
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => []);
    when(() => repository.payrollCatalog(company: 'شرکت تست'))
        .thenAnswer((_) async => []);

    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_widget(repository, width: 320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قالب حکم استخدام'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('قالب پیش‌فرض حکم استخدام'), findsOneWidget);
  });
}
