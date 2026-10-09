import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_field_widgets.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

RequestFormController _controller(WidgetTester tester) => tester
    .widget<RequestFieldWidget>(find.byType(RequestFieldWidget).first)
    .controller;

Future<void> _pump(
    WidgetTester tester, FakeRequestRepository repository) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(
      SupplyRequestFormPage(repository: repository, type: typeOf('supply'))));
  await tester.pumpAndSettle();
}

Finder _submit() => find.widgetWithText(FilledButton, 'ثبت درخواست');

void main() {
  testWidgets('shows the supply sections of the mockup', (tester) async {
    await _pump(tester, FakeRequestRepository());
    for (final text in [
      'درخواست تأمین کالا / خدمت',
      'اطلاعات اصلی',
      'اقلام / خدمات',
      'تأمین‌کننده پیشنهادی',
      'شرایط و توضیحات',
      'پیوست‌ها',
      'محل تحویل *',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // Supply methods are chips with Persian labels.
    for (final label in ['از انبار', 'خرید', 'انتقال', 'قرارداد', 'نامشخص']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
  });

  testWidgets('delivery locations are grouped by kind', (tester) async {
    await _pump(tester, FakeRequestRepository());
    await tester.tap(find.text('محل تحویل *'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('انبار'), findsOneWidget);
    expect(find.text('شعبه'), findsOneWidget);
    expect(find.text('واحد سازمانی'), findsWidgets);
    expect(find.text('انبار مرکزی'), findsOneWidget);
    await tester.tap(find.text('بخش ICU').last);
    await tester.pumpAndSettle();
    expect(_controller(tester).value('delivery_location'),
        'department:ICU - DEMO');
  });

  testWidgets('only the contract fields are required', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    final controller = _controller(tester);
    expect(repository.created, isEmpty);
    expect(controller.subjectError, isNotNull);
    for (final key in ['delivery_location', 'needed_date', 'items']) {
      expect(controller.errorFor(key), isNotNull, reason: key);
    }
    // Optional: method, supplier, priority, notes.
    for (final key in [
      'supply_method',
      'suggested_supplier',
      'priority',
      'reason'
    ]) {
      expect(controller.errorFor(key), isNull, reason: key);
    }
  });

  testWidgets('a transfer to a non-warehouse is blocked in the form',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await enterText(
        tester, find.byKey(const ValueKey('template-subject')), 'انتقال کالا');
    final controller = _controller(tester)
      ..setValue('delivery_location', 'branch:Tehran', label: 'تهران')
      ..setValue('needed_date', '2026-10-20')
      ..setValue('items', [
        {'item_code': 'MON-XS', 'qty': 1, 'uom': 'Nos'}
      ])
      ..setValue('supply_method', 'Transfer');
    await tester.pump();
    expect(
        controller.errorFor('delivery_location'), supplyTransferNeedsWarehouse);
    expect(find.text(supplyTransferNeedsWarehouse), findsOneWidget);

    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(repository.created, isEmpty);

    // A warehouse as destination clears it.
    controller.setValue('delivery_location', 'warehouse:Stores - DEMO',
        label: 'انبار مرکزی');
    await tester.pump();
    expect(controller.errorFor('delivery_location'), isNull);
    // Another method does not care.
    controller
      ..setValue('delivery_location', 'branch:Tehran', label: 'تهران')
      ..setValue('supply_method', 'Purchase');
    await tester.pump();
    expect(controller.errorFor('delivery_location'), isNull);
  });

  testWidgets('a service item is blocked for warehouse and transfer supply',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    final controller = _controller(tester)
      ..setValue('items', [
        {'item_code': 'MON-XS', 'qty': 1, 'uom': 'Nos', 'is_stock_item': 1},
        {'item_code': 'SRV-REPAIR', 'qty': 1, 'uom': 'Nos', 'is_stock_item': 0},
      ])
      ..setValue('supply_method', 'Warehouse');
    await tester.pump();
    expect(controller.errorFor('items'), supplyNonStockItemMessage);

    // Purchase supply accepts services.
    controller.setValue('supply_method', 'Purchase');
    await tester.pump();
    expect(controller.errorFor('items'), isNull);

    // Rows without the flag (a stored request being edited) are left to the server.
    controller
      ..setValue('items', [
        {'item_code': 'SRV-REPAIR', 'qty': 1, 'uom': 'Nos'}
      ])
      ..setValue('supply_method', 'Transfer');
    await tester.pump();
    expect(controller.errorFor('items'), isNull);
  });

  testWidgets('submit sends the supply payload without empty optional values',
      (tester) async {
    final repository = FakeRequestRepository()
      ..createResult = {
        'name': 'SP-1405-0001',
        'subject': 'تأمین',
        'template_key': 'supply',
        'values': <String, dynamic>{},
      };
    await _pump(tester, repository);
    await enterText(
        tester, find.byKey(const ValueKey('template-subject')), 'تأمین ICU');
    _controller(tester)
      ..setValue('delivery_location', 'warehouse:Stores - DEMO',
          label: 'انبار مرکزی')
      ..setValue('needed_date', '2026-10-20')
      ..setValue('items', [
        {
          'item_code': 'SVC-INSTALL',
          'qty': 1,
          'uom': 'Nos',
          'description': 'نصب'
        }
      ]);
    await tester.pump();
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(repository.created.single.data, {
      'template_key': 'supply',
      'subject': 'تأمین ICU',
      'values': {
        'requester': 'ali@asoud.test',
        'org_unit': 'ICU - DEMO',
        'delivery_location': 'warehouse:Stores - DEMO',
        'needed_date': '2026-10-20',
        'supply_method': 'Unspecified',
        'priority': 'Normal',
        'items': [
          {
            'item_code': 'SVC-INSTALL',
            'qty': 1,
            'uom': 'Nos',
            'description': 'نصب'
          }
        ],
      },
      'attachments': <Map<String, String>>[],
    });
  });
}
