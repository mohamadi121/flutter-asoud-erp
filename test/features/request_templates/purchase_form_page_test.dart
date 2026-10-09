import 'dart:typed_data';

import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_field_widgets.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

RequestFormController _controller(WidgetTester tester) => tester
    .widget<RequestFieldWidget>(find.byType(RequestFieldWidget).first)
    .controller;

Future<void> _pump(WidgetTester tester, FakeRequestRepository repository,
    {bool costCenterRequired = true, RequestFilePicker? picker}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(PurchaseRequestFormPage(
      repository: repository,
      filePicker: picker,
      type: typeOf('purchase', costCenterRequired: costCenterRequired))));
  await tester.pumpAndSettle();
}

Finder _submit() => find.widgetWithText(FilledButton, 'ثبت درخواست');

void main() {
  testWidgets('shows the three sections of the mockup', (tester) async {
    await _pump(tester, FakeRequestRepository());
    expect(find.text('درخواست خرید'), findsOneWidget);
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
    expect(find.text('اقلام درخواست'), findsOneWidget);
    expect(find.text('پیوست‌ها'), findsOneWidget);
    expect(find.text('عنوان درخواست *'), findsOneWidget);
    expect(find.text('مرکز هزینه *'), findsOneWidget);
    expect(find.text('اولویت *'), findsOneWidget);
    for (final label in ['عادی', 'مهم', 'فوری']) {
      expect(find.text(label), findsWidgets);
    }
    // The defaults come from the signed-in user.
    expect(find.text('علی محمدی'), findsWidgets);
    expect(find.text('بخش ICU'), findsWidgets);
    expect(find.text('انصراف'), findsOneWidget);
  });

  testWidgets('every required field blocks the submit', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    final controller = _controller(tester);
    expect(repository.created, isEmpty);
    expect(controller.subjectError, isNotNull);
    for (final key in [
      'cost_center',
      'needed_date',
      'reason',
      'items',
    ]) {
      expect(controller.errorFor(key), isNotNull, reason: key);
    }
    for (final key in ['requester', 'org_unit', 'priority']) {
      expect(controller.errorFor(key), isNull, reason: key);
    }
    expect(find.text('لطفاً خطاهای فرم را برطرف کنید.'), findsOneWidget);
  });

  testWidgets('cost center is optional when the company does not require it',
      (tester) async {
    final repository = FakeRequestRepository(costCenterRequired: false);
    await _pump(tester, repository, costCenterRequired: false);
    expect(find.text('مرکز هزینه'), findsOneWidget);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(_controller(tester).errorFor('cost_center'), isNull);
  });

  testWidgets('adding an item fills the code and the unit automatically',
      (tester) async {
    await _pump(tester, FakeRequestRepository());
    await tester.ensureVisible(find.text('افزودن کالا'));
    await tester.tap(find.text('افزودن کالا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('کاغذ A4').last);
    await tester.pumpAndSettle();
    final items = _controller(tester).value('items') as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['item_code'], 'PREVIEW-PAPER');
    expect((items.first as Map)['uom'], 'بسته');
    expect((items.first as Map)['qty'], 1);
    expect(find.text('PREVIEW-PAPER'), findsWidgets);
  });

  testWidgets('submit sends exactly the create_request payload',
      (tester) async {
    final repository = FakeRequestRepository()
      ..createResult = {
        'name': 'PR-1405-0001',
        'subject': 'خرید تجهیزات ICU',
        'template_key': 'purchase',
        'values': <String, dynamic>{},
      };
    await _pump(tester, repository);
    await enterText(tester, find.byKey(const ValueKey('template-subject')),
        'خرید تجهیزات ICU');
    final controller = _controller(tester);
    controller
      ..setValue('cost_center', 'MED - DEMO', label: 'تجهیزات پزشکی')
      ..setValue('project', 'PRJ-ICU-1404', label: 'توسعه بخش ICU')
      ..setValue('needed_date', '2026-10-20')
      ..setValue('priority', 'High')
      ..setValue('reason', 'تأمین تجهیزات مانیتورینگ')
      ..setValue('items', [
        {'item_code': 'MON-XS', 'qty': 2, 'uom': 'Nos', 'note': 'فوری'}
      ]);
    await tester.pump();
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    final sent = repository.created.single;
    expect(sent.requestId, startsWith('request-'));
    expect(sent.data, {
      'template_key': 'purchase',
      'subject': 'خرید تجهیزات ICU',
      'values': {
        'requester': 'ali@asoud.test',
        'org_unit': 'ICU - DEMO',
        'cost_center': 'MED - DEMO',
        'project': 'PRJ-ICU-1404',
        'needed_date': '2026-10-20',
        'priority': 'High',
        'reason': 'تأمین تجهیزات مانیتورینگ',
        'items': [
          {'item_code': 'MON-XS', 'qty': 2, 'uom': 'Nos', 'note': 'فوری'}
        ],
      },
      'attachments': <Map<String, String>>[],
    });
    // The «ثبت شد» page follows.
    expect(find.text('درخواست شما با موفقیت ثبت شد'), findsOneWidget);
  });

  testWidgets('attachments respect the type and size limits', (tester) async {
    Future<List<RequestPickedFile>> pick(
            RequestAttachmentLimits limits) async =>
        [
          (filename: 'virus.exe', bytes: Uint8List(10)),
        ];
    await _pump(tester, FakeRequestRepository(), picker: pick);
    await tester.ensureVisible(
        find.byKey(const ValueKey('request-attachments-dropzone')));
    await tester
        .tap(find.byKey(const ValueKey('request-attachments-dropzone')));
    await tester.pumpAndSettle();
    final controller = _controller(tester);
    expect(controller.generalDrafts, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);

    expect(controller.attachmentError('big.pdf', 11 * 1024 * 1024), isNotNull);
    expect(controller.attachmentError('ok.pdf', 1024), isNull);
    expect(controller.attachmentError('sheet.xlsx', 1024), isNull);
    expect(controller.attachmentError('a.doc', 1024), isNull);
  });

  testWidgets('a server rejection is shown and the form stays', (tester) async {
    final repository = FakeRequestRepository()
      ..createError = StateError('تاریخ مورد نیاز گذشته است.');
    await _pump(tester, repository);
    await enterText(
        tester, find.byKey(const ValueKey('template-subject')), 'خرید');
    _controller(tester)
      ..setValue('cost_center', 'MED - DEMO')
      ..setValue('needed_date', '2026-10-20')
      ..setValue('reason', 'دلیل')
      ..setValue('items', [
        {'item_code': 'MON-XS', 'qty': 1, 'uom': 'Nos'}
      ]);
    await tester.pump();
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(find.text('تاریخ مورد نیاز گذشته است.'), findsOneWidget);
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
  });

  testWidgets('editing loads the request and saves through update_request',
      (tester) async {
    final repository = FakeRequestRepository();
    final existing = await repository.detail('PR-1404-0023');
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapPage(PurchaseRequestFormPage(
        repository: repository, type: typeOf('purchase'), existing: existing)));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش درخواست خرید'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ذخیره تغییرات'), findsOneWidget);
    final controller = _controller(tester);
    expect(controller.subject.text, 'خرید تجهیزات پزشکی بخش ICU');
    expect(controller.value('priority'), 'High');
    await enterText(tester, find.byKey(const ValueKey('template-subject')),
        'خرید تجهیزات ICU (اصلاح‌شده)');
    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(repository.created, isEmpty);
    final call = repository.updated.single;
    expect(call['name'], 'PR-1404-0023');
    expect(call['subject'], 'خرید تجهیزات ICU (اصلاح‌شده)');
    expect((call['values'] as Map)['priority'], 'High');
    expect(((call['values'] as Map)['items'] as List), hasLength(3));
    expect(call['attachments'], isNull);
    expect(call['remove'], isNull);
  });
}
