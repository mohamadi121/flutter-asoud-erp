import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:asoud_erp/features/workflows/data/request_demo_source.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_field_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(page));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RequestScreenRegistry.clear();
    RequestDemoRegistry.clear();
    registerRequestTemplates();
  });
  tearDown(() {
    RequestScreenRegistry.clear();
    RequestDemoRegistry.clear();
  });

  test('registration is idempotent and covers the three templates', () {
    registerRequestTemplates();
    expect(RequestScreenRegistry.keys, {'purchase', 'supply', 'leave'});
    for (final key in ['purchase', 'supply', 'leave']) {
      final screens = RequestScreenRegistry.of(key)!;
      expect(screens.form, isNotNull);
      expect(screens.detail, isNotNull);
      expect(screens.list, isNotNull);
      expect(screens.cardBuilder, isNotNull);
    }
    expect(RequestDemoRegistry.sources, hasLength(1));
  });

  test('the preview offers the three system types first', () async {
    final types = await previewRepository().options();
    expect(types.take(3).map((row) => row['template_key']),
        ['purchase', 'supply', 'leave']);
    expect(types.take(3).map((row) => row['workflow_title']), [
      'درخواست خرید کالا',
      'درخواست تأمین کالا / خدمت',
      'درخواست مرخصی',
    ]);
  });

  testWidgets(
      'the purchase list shows the mockup rows in RTL with Persian '
      'dates', (tester) async {
    final repository = previewRepository();
    await _pump(
        tester,
        PurchaseRequestsListPage(
            company: repository.company, repository: repository));
    final context = tester.element(find.byType(PurchaseRequestsListPage));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('درخواست‌های خرید'), findsOneWidget);
    for (final number in [
      'PR-1404-0023',
      'PR-1404-0022',
      'PR-1404-0021',
      'PR-1404-0020'
    ]) {
      expect(find.text(number), findsOneWidget, reason: number);
    }
    expect(find.text('خرید تجهیزات پزشکی بخش ICU'), findsOneWidget);
    expect(find.text('ارسال شده'), findsWidgets);
    expect(find.text('تأیید شده'), findsWidgets);
    expect(find.text('رد شده'), findsWidgets);
    // Jalali dates with Persian digits only.
    final dates = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where(
            (text) => RegExp(r'^[۰-۹]{4}/[۰-۹]{2}/[۰-۹]{2}$').hasMatch(text));
    expect(dates, isNotEmpty);
    expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data ?? '')
            .where((text) => RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(text)),
        isEmpty);
  });

  testWidgets('the leave list shows LV-1404-0042, -0041 and the rejected -0040',
      (tester) async {
    final repository = previewRepository();
    await _pump(
        tester,
        LeaveRequestsListPage(
            company: repository.company, repository: repository));
    for (final number in [
      'LV-1404-0042',
      'LV-1404-0041',
      'LV-1404-0040',
      'LV-1404-0039',
      'LV-1404-0038'
    ]) {
      expect(find.text(number), findsOneWidget, reason: number);
    }
    expect(find.text('۳ روز'), findsOneWidget);
    expect(find.text('۴ ساعت'), findsOneWidget);
    expect(find.text('به دلیل مدارک ناقص'), findsOneWidget);
  });

  testWidgets('the supply list shows the demo rows', (tester) async {
    final repository = previewRepository();
    await _pump(
        tester,
        SupplyRequestsListPage(
            company: repository.company, repository: repository));
    expect(find.text('SP-1404-0007'), findsOneWidget);
    expect(find.text('SP-1404-0006'), findsOneWidget);
    expect(find.text('از انبار'), findsOneWidget);
    expect(find.text('خرید'), findsOneWidget);
  });

  testWidgets('a card opens the registered detail with items and comments',
      (tester) async {
    final repository = previewRepository();
    await _pump(
        tester,
        PurchaseRequestsListPage(
            company: repository.company, repository: repository));
    await tester.tap(find.text('PR-1404-0023'));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseRequestDetailPage), findsOneWidget);
    expect(find.text('جزئیات درخواست خرید'), findsOneWidget);
    expect(find.text('اقلام درخواست (۳ قلم)'), findsOneWidget);
    expect(find.text('مانیتور بیمارستانی مدل XS'), findsOneWidget);
    expect(find.text('توسعه بخش ICU'), findsWidgets);
    expect(find.textContaining('مشخصات فنی پیوست شد'), findsOneWidget);
  });

  testWidgets('cancelling a sample row explains that it is a demo',
      (tester) async {
    final repository = previewRepository();
    await _pump(tester,
        SupplyRequestDetailPage(repository: repository, name: 'SP-1404-0007'));
    await tester.tap(find.text('انصراف درخواست'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'لغو درخواست'));
    await tester.pumpAndSettle();
    // The page keeps the request; the repository explains why it refused.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('SP-1404-0007'), findsOneWidget);
    expect(repository.isSampleRequest('SP-1404-0007'), isTrue);
    await expectLater(
        repository.cancel('SP-1404-0007'),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            'درخواست نمایشی قابل لغو نیست؛ یک درخواست جدید ثبت کنید.')));
  });

  testWidgets('a leave saved in the preview stays on the device',
      (tester) async {
    final repository = previewRepository();
    final type = (await repository.options())
        .firstWhere((row) => row['template_key'] == 'leave');
    await _pump(
        tester, LeaveRequestFormPage(repository: repository, type: type));
    final controller = tester
        .widget<RequestFieldWidget>(find.byType(RequestFieldWidget).first)
        .controller;
    controller
      ..setValue('leave_type', 'Casual Leave', label: 'سالانه')
      ..setValue('start_date', '2026-10-10')
      ..setValue('end_date', '2026-10-12')
      ..setValue('reason', 'سفر');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('۳ روز'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'ثبت درخواست'));
    await tester.pumpAndSettle();
    expect(find.text('درخواست شما روی گوشی ذخیره شد'), findsOneWidget);
    expect(find.textContaining('LOCAL-'), findsWidgets);
    // The list shows it first, as a local preview row.
    final list = await repository.listPage(templateKey: 'leave');
    expect(list.items.first.localPreview, isTrue);
    expect(list.items.length, 6);
  });
}
