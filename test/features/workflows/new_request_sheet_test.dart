import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/new_request_catalog.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/new_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _types = <Map<String, dynamic>>[
  {
    'workflow_title': 'درخواست خرید کالا',
    'short_title': 'تهیه کالا',
    'module_key': 'Purchase',
    'icon_key': 'purchase',
  },
  {
    'workflow_title': 'درخواست معرفی تأمین‌کننده',
    'short_title': 'ثبت فروشنده',
    'module_key': 'Purchase',
    'icon_key': 'purchase',
  },
  {
    'workflow_title': 'درخواست مرخصی',
    'short_title': 'مرخصی سالانه',
    'module_key': 'HR',
    'icon_key': 'leave',
  },
  {'workflow_title': 'پیش‌نویس', 'active': false},
];

Widget _host(Future<List<Map<String, dynamic>>> Function() load) => MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () =>
                          showNewRequestSheet(context, loadTypes: load),
                      child: const Text('باز کردن'))))),
    );

void main() {
  test('every module has its own subgroups and the bank maps into them', () {
    for (final module in [
      'منابع انسانی',
      'مالی',
      'خرید',
      'انبار',
      'فروش',
      'فناوری اطلاعات',
      'سایر'
    ]) {
      final list = subgroupsForModule(module);
      expect(list.first, 'همه درخواست‌ها');
      expect(list.last, 'سایر');
    }
    expect(subgroupsForModule('همه'), ['همه درخواست‌ها']);
    expect(subgroupsForModule('منابع انسانی'), [
      'همه درخواست‌ها',
      'مرخصی و مأموریت',
      'حضور و غیاب',
      'مالی پرسنلی',
      'گواهی و مدارک',
      'آموزش و تجهیزات',
      'سایر'
    ]);
    expect(hrRequestBank.length, 10);
    for (final row in [...hrRequestBank, ...purchaseRequestBank]) {
      expect(subgroupsForModule(row.module), contains(row.subgroup));
      expect(row.description, isNotEmpty);
    }
    expect(
        requestSubgroup({'workflow_title': 'درخواست مساعده'}), 'مالی پرسنلی');
    expect(requestModule({'workflow_title': 'درخواست مساعده'}), 'منابع انسانی');
    // server types: unknown or missing subgroup falls back to «سایر».
    expect(
        requestSubgroup(
            {'workflow_title': 'x', 'module_key': 'HR', 'request_subgroup': 'حضور و غیاب'}),
        'حضور و غیاب');
    expect(
        requestSubgroup(
            {'workflow_title': 'x', 'module_key': 'HR', 'request_subgroup': 'نامعتبر'}),
        'سایر');
    expect(requestSubgroup({'workflow_title': 'x', 'module_key': 'Stock'}),
        'سایر');
  });

  testWidgets('selecting منابع انسانی shows its subgroups and filters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final types = [
      for (final row in hrRequestBank)
        {
          'workflow_title': row.title,
          'short_title': row.description,
          'icon_key': 'leave',
        },
    ];
    await tester.pumpWidget(_host(() async => types));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-request-module-منابع انسانی')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('new-request-count')),
        matching: find.byType(Text))).data, '10');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    for (final name in subgroupsForModule('منابع انسانی').skip(1).take(4)) {
      expect(find.text(name), findsWidgets);
    }
    await tester.tap(find.text('حضور و غیاب').last);
    await tester.pumpAndSettle();
    expect(find.text('درخواست اضافه‌کاری'), findsOneWidget);
    expect(tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('new-request-count')),
        matching: find.byType(Text))).data, '3');
    expect(find.text('درخواست مساعده'), findsNothing);
    expect(find.text('اصلاح ورود یا خروج ثبت‌نشده یا نادرست'), findsOneWidget);
  });

  test('filter applies visibility, module, subgroup, keywords and count', () {
    expect(filterNewRequestTypes(_types).length, 3);
    expect(filterNewRequestTypes(_types, module: 'خرید').length, 2);
    expect(
        filterNewRequestTypes(_types, module: 'خرید', subgroup: 'تأمین‌کنندگان')
            .single['workflow_title'],
        'درخواست معرفی تأمین‌کننده');
    expect(
        filterNewRequestTypes(_types, query: 'فروشنده')
            .single['workflow_title'],
        'درخواست معرفی تأمین‌کننده');
    expect(
        filterNewRequestTypes(_types, query: 'سالانه').single['workflow_title'],
        'درخواست مرخصی');
  });

  testWidgets('opens, filters and selects a type at 360 and 320 widths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(() async => _types));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب درخواست جدید'), findsOneWidget);
    expect(find.text('پیش‌نویس'), findsNothing);
    await tester.tap(find.byKey(const Key('new-request-module-خرید')));
    await tester.pump();
    expect(find.text('درخواست‌های خرید'), findsOneWidget);
    expect(find.text('زیرگروه درخواست'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'فروشنده');
    await tester.pump();
    expect(find.text('درخواست معرفی تأمین‌کننده'), findsOneWidget);
    await tester.tap(find.text('درخواست معرفی تأمین‌کننده'));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب درخواست جدید'), findsNothing);
  });

  testWidgets('close and retry error state work', (tester) async {
    var attempts = 0;
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(() async {
      attempts++;
      if (attempts == 1) throw StateError('network');
      return _types;
    }));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('دریافت درخواست‌ها ممکن نشد.'), findsOneWidget);
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('درخواست مرخصی'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-request-close')));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب درخواست جدید'), findsNothing);
  });

  testWidgets('subgroup shows only for a module and resets on module change',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(() async => _types));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(find.text('زیرگروه درخواست'), findsNothing);
    expect(find.text('همه درخواست‌ها'), findsOneWidget);
    expect(tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('new-request-count')),
        matching: find.byType(Text))).data, '3');
    await tester.tap(find.byKey(const Key('new-request-module-خرید')));
    await tester.pump();
    expect(find.text('درخواست‌های خرید'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأمین‌کنندگان').last);
    await tester.pumpAndSettle();
    expect(find.text('درخواست خرید کالا'), findsNothing);
    expect(find.text('درخواست معرفی تأمین‌کننده'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-request-module-منابع انسانی')));
    await tester.pump();
    expect(find.text('درخواست مرخصی'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-request-module-خرید')));
    await tester.pump();
    expect(find.text('درخواست خرید کالا'), findsOneWidget);
  });

  testWidgets('empty state and keyboard inset do not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(() async => _types));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    await tester.dragUntilVisible(find.text('درخواستی پیدا نشد'),
        find.byType(ListView).first, const Offset(0, -120));
    expect(find.text('درخواستی پیدا نشد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrim tap closes the sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(() async => _types));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 10));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب درخواست جدید'), findsNothing);
  });
}
