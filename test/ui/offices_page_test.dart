import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/presentation/cubit/offices_cubit.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_type_page.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/offices_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';

import '../helpers/fake_office_repository.dart';

final defaultOffice = Office(
  name: 'شرکت نمونه توسعه آریا',
  type: OfficeType.legal,
  fiscalYearStart: DateTime(2026),
);
final secondOffice = Office(
  name: 'فروشگاه ایرانیان',
  type: OfficeType.personal,
  fiscalYearStart: DateTime(2026),
);

Widget app(Widget child) => RepositoryProvider<OfficeRepository>.value(
      value: FakeOfficeRepository(
          offices: [defaultOffice, secondOffice], defaultOffice: defaultOffice),
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

void main() {
  for (final size in const [Size(360, 800), Size(390, 844), Size(430, 932)]) {
    testWidgets('صفحه دفترها در اندازه $size overflow ندارد', (tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(app(OfficesPage(
        initialState: OfficesState(
          status: OfficesStatus.success,
          offices: [defaultOffice, secondOffice],
          defaultOffice: defaultOffice,
          showCreatedBanner: true,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('دفترهای من'), findsOneWidget);
      expect(find.text('ورود به دفتر کار'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets(
      'حالت‌های loading empty error بدون موفقیت ساختگی نمایش داده می‌شوند',
      (tester) async {
    await tester.pumpWidget(app(OfficesPage(
        initialState: OfficesState(status: OfficesStatus.loading))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(const OfficesPage(
        initialState: OfficesState(status: OfficesStatus.empty))));
    await tester.pump();
    expect(find.text('هنوز دفتری ندارید'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(const OfficesPage(
        initialState:
            OfficesState(status: OfficesStatus.error, message: 'خطای سرور'))));
    await tester.pumpAndSettle();
    expect(find.text('خطای سرور'), findsOneWidget);
    expect(find.text('دفتر کار با موفقیت ایجاد شد'), findsNothing);
  });

  testWidgets('جست‌وجو، منوی عملیات و navigation فرم کار می‌کنند',
      (tester) async {
    await tester.pumpWidget(app(OfficesPage(
      initialState: OfficesState(
        status: OfficesStatus.success,
        offices: [defaultOffice, secondOffice],
        defaultOffice: defaultOffice,
      ),
    )));
    await tester.enterText(
        find.byKey(const ValueKey('office-search')), 'ناموجود');
    await tester.pump();
    expect(find.text('دفتری با این عبارت پیدا نشد.'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('office-menu-شرکت نمونه توسعه آریا')));
    await tester.pumpAndSettle();
    expect(find.text('عملیات دفتر'), findsOneWidget);
    expect(find.text('حذف دفتر'), findsOneWidget);
    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ایجاد دفتر کار جدید'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficeTypePage), findsOneWidget);
  });

  testWidgets('کنترل حقیقی و حقوقی 48 پیکسل و تمام‌عرض است', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(app(const OfficeTypePage()));
    await tester.pumpAndSettle();
    final personal = find.byKey(const ValueKey('office-type-personal'));
    final legal = find.byKey(const ValueKey('office-type-legal'));
    expect(tester.getSize(personal).height, inInclusiveRange(40, 42));
    expect(tester.getSize(personal).width,
        closeTo(tester.getSize(legal).width, .1));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('مسیر آفلاین دفترها به دفتر کار و تنظیمات پایه باز است',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(app(OfficesPage(
      initialState: OfficesState(
        status: OfficesStatus.success,
        offices: [defaultOffice],
        defaultOffice: defaultOffice,
        offlinePreview: true,
      ),
    )));
    await tester.tap(find.text('ورود به دفتر کار'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.textContaining('حالت موقت آفلاین'), findsOneWidget);

    await tester.tap(find.text('تکمیل'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseAccountingSetupPage), findsOneWidget);
    expect(find.textContaining('پیش‌نمایش آفلاین'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
