import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
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
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(
      LeaveRequestFormPage(repository: repository, type: typeOf('leave'))));
  await tester.pumpAndSettle();
}

/// Lets the 400 ms preview debounce fire and the answer land.
Future<void> _preview(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

Finder _submit() => find.widgetWithText(FilledButton, 'ثبت درخواست');

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit());

void main() {
  testWidgets('shows the leave form of the mockup', (tester) async {
    await _pump(tester, FakeRequestRepository());
    for (final text in [
      'درخواست مرخصی',
      'اطلاعات اصلی',
      'نوع مرخصی *',
      'روزانه',
      'ساعتی',
      'تاریخ شروع *',
      'تاریخ پایان *',
      'مدت مرخصی',
      'محل خدمت',
      'دلیل مرخصی *',
      'پیوست‌ها (اختیاری)',
      'اطلاعات باقی‌مانده مرخصی',
      'انصراف',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // The hourly block is hidden for a daily request.
    expect(find.text('تاریخ مرخصی *'), findsNothing);
    expect(find.text('ساعت شروع *'), findsNothing);
  });

  testWidgets('the balance panel shows annual, sick and other', (tester) async {
    await _pump(tester, FakeRequestRepository());
    expect(find.text('ماندهٔ سالانه'), findsOneWidget);
    expect(find.text('استعلاجی'), findsWidgets);
    expect(find.text('سایر'), findsWidgets);
    expect(find.text('۱۲٫۵ روز'), findsOneWidget);
    expect(find.text('۸ روز'), findsOneWidget);
    expect(find.text('۲ روز'), findsOneWidget);
    // `unpaid` is never listed.
    expect(find.text('بدون حقوق'), findsNothing);
  });

  testWidgets(
      'toggling روزانه / ساعتی swaps the blocks and drops hidden values',
      (tester) async {
    await _pump(tester, FakeRequestRepository());
    final controller = _controller(tester)
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-12');
    await tester.pump();
    expect(controller.value('start_date'), '2026-10-10');

    await tester.tap(find.text('ساعتی'));
    await tester.pumpAndSettle();
    expect(find.text('تاریخ شروع *'), findsNothing);
    expect(find.text('تاریخ پایان *'), findsNothing);
    expect(find.text('تاریخ مرخصی *'), findsOneWidget);
    expect(find.text('ساعت شروع *'), findsOneWidget);
    expect(find.text('ساعت پایان *'), findsOneWidget);
    expect(controller.value('start_date'), isNull);
    expect(controller.value('end_date'), isNull);
    expect(controller.value('request_kind'), 'Hourly');

    controller
      ..setValue('leave_date', '2026-10-10')
      ..setValue('start_time', '10:00')
      ..setValue('end_time', '14:00');
    await tester.pump();
    await tester.tap(find.text('روزانه'));
    await tester.pumpAndSettle();
    expect(find.text('تاریخ شروع *'), findsOneWidget);
    expect(find.text('ساعت شروع *'), findsNothing);
    expect(controller.value('leave_date'), isNull);
    expect(controller.value('start_time'), isNull);
    expect(controller.value('end_time'), isNull);
    expect(controller.payloadValues().keys,
        isNot(containsAll(['leave_date', 'start_time'])));
  });

  testWidgets('the duration badge shows «۳ روز» for a daily request',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    expect(find.text('—'), findsOneWidget);
    _controller(tester)
      ..setValue('leave_type', 'Casual Leave', label: 'سالانه')
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-12');
    await tester.pump();
    // Nothing is asked before the debounce elapses.
    expect(repository.previewCalls, isEmpty);
    await _preview(tester);
    expect(repository.previewCalls.single, {
      'leave_type': 'Casual Leave',
      'request_kind': 'Daily',
      'start_date': '2026-10-10',
      'end_date': '2026-10-12',
    });
    expect(find.text('۳ روز'), findsOneWidget);
    // The panel shows what is left after this request.
    expect(find.text('پس از این درخواست: ۹٫۵ روز'), findsOneWidget);
  });

  testWidgets('the duration badge shows «۴ ساعت» for an hourly request',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await tester.tap(find.text('ساعتی'));
    await tester.pumpAndSettle();
    _controller(tester)
      ..setValue('leave_type', 'Sick Leave', label: 'استعلاجی')
      ..setValue('leave_date', '2026-10-10')
      ..setValue('start_time', '10:00')
      ..setValue('end_time', '14:00');
    await _preview(tester);
    expect(repository.previewCalls.single['request_kind'], 'Hourly');
    expect(find.text('۴ ساعت'), findsOneWidget);
  });

  testWidgets('rapid edits ask the preview once (400 ms debounce)',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    final controller = _controller(tester)
      ..setValue('leave_type', 'Casual Leave')
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-11');
    await tester.pump(const Duration(milliseconds: 200));
    controller.setValue('end_date', '2026-10-13');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.previewCalls, isEmpty);
    await _preview(tester);
    expect(repository.previewCalls, hasLength(1));
    expect(repository.previewCalls.single['end_date'], '2026-10-13');
  });

  testWidgets('a preview error disables the submit and shows the message',
      (tester) async {
    final repository = FakeRequestRepository()
      ..previewHandler = (args) async => LeavePreview.fromMap({
            'valid': false,
            'errors': [
              {
                'code': 'INSUFFICIENT_LEAVE_BALANCE',
                'field': 'leave_type',
                'message': 'مانده مرخصی کافی نیست.'
              }
            ],
            'duration': {
              'unit': 'day',
              'days': 20.0,
              'hours': null,
              'day_equivalent': 20.0
            },
          });
    await _pump(tester, repository);
    expect(_submitButton(tester).onPressed, isNotNull);
    _controller(tester)
      ..setValue('leave_type', 'Casual Leave', label: 'سالانه')
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-30')
      ..setValue('reason', 'سفر');
    await _preview(tester);
    expect(find.byKey(const ValueKey('leave-preview-error')), findsOneWidget);
    expect(find.text('مانده مرخصی کافی نیست.'), findsWidgets);
    expect(_submitButton(tester).onPressed, isNull);
    await tester.tap(_submit(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repository.created, isEmpty);

    // Fixing the dates lifts the block.
    repository.previewHandler = null;
    _controller(tester).setValue('end_date', '2026-10-12');
    await _preview(tester);
    expect(find.byKey(const ValueKey('leave-preview-error')), findsNothing);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('submit sends the daily payload without a subject',
      (tester) async {
    final repository = FakeRequestRepository()
      ..createResult = {
        'name': 'LV-1405-0001',
        'subject': 'مرخصی سالانه (روزانه)',
        'template_key': 'leave',
        'values': <String, dynamic>{},
      };
    await _pump(tester, repository);
    _controller(tester)
      ..setValue('leave_type', 'Casual Leave', label: 'سالانه')
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-12')
      ..setValue('reason', 'سفر شخصی');
    await _preview(tester);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(repository.created, hasLength(1));
    expect(repository.created.single.data, {
      'template_key': 'leave',
      'values': {
        'requester': 'ali@asoud.test',
        'org_unit': 'ICU - DEMO',
        'leave_type': 'Casual Leave',
        'request_kind': 'Daily',
        'start_date': '2026-10-10',
        'end_date': '2026-10-12',
        'location': 'Tehran',
        'reason': 'سفر شخصی',
      },
      'attachments': <Map<String, String>>[],
    });
    expect(find.text('درخواست شما با موفقیت ثبت شد'), findsOneWidget);
  });

  testWidgets('submit sends the hourly payload with times and no day fields',
      (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await tester.tap(find.text('ساعتی'));
    await tester.pumpAndSettle();
    _controller(tester)
      ..setValue('leave_type', 'Sick Leave', label: 'استعلاجی')
      ..setValue('leave_date', '2026-10-10')
      ..setValue('start_time', '10:00')
      ..setValue('end_time', '14:00')
      ..setValue('reason', 'معاینه پزشک');
    await _preview(tester);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    final values = repository.created.single.data['values'] as Map;
    expect(values, {
      'requester': 'ali@asoud.test',
      'org_unit': 'ICU - DEMO',
      'leave_type': 'Sick Leave',
      'request_kind': 'Hourly',
      'leave_date': '2026-10-10',
      'start_time': '10:00',
      'end_time': '14:00',
      'location': 'Tehran',
      'reason': 'معاینه پزشک',
    });
    expect(values.containsKey('duration'), isFalse);
    expect(repository.created.single.data.containsKey('subject'), isFalse);
  });

  testWidgets('required fields block the submit', (tester) async {
    final repository = FakeRequestRepository();
    await _pump(tester, repository);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    final controller = _controller(tester);
    expect(repository.created, isEmpty);
    for (final key in ['leave_type', 'start_date', 'end_date', 'reason']) {
      expect(controller.errorFor(key), isNotNull, reason: key);
    }
  });
}
