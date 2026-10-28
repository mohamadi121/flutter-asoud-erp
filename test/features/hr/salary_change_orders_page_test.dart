import 'package:asoud_erp/features/hr/data/salary_change_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/salary_change_orders_page.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements SalaryChangeOrderRepository {}

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
  });

  Widget createWidget({required double width, bool allowWrites = true}) {
    return MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: child!,
        ),
      ),
      home: SalaryChangeOrdersPage(
        company: 'شرکت تابان',
        repository: repository,
        canIssue: allowWrites,
        canDesign: allowWrites,
        canExecutePayroll: allowWrites,
      ),
    );
  }

  testWidgets('write controls require explicit permissions', (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تابان',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تابان'))
        .thenAnswer((_) async => null);
    when(() => repository.people(company: 'شرکت تابان'))
        .thenAnswer((_) async => []);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: SalaryChangeOrdersPage(
        company: 'شرکت تابان',
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('＋ حکم تغییر حقوق جدید'), findsNothing);
    expect(find.text('ویرایش و انتشار قالب حکم'), findsNothing);
  });

  testWidgets(
      'renders salary change orders list at 320, 390 and 430 px without overflow',
      (tester) async {
    const orders = [
      SalaryChangeOrderSummary(
        name: 'ENTRY-1',
        number: 'SAL-1405-001',
        employee: 'HR-101',
        employeeName: 'علی رضایی',
        status: 'draft',
        statusLabel: 'پیش‌نویس',
        applicationStatus: 'not_applied',
        applicationStatusLabel: 'اعمال‌نشده',
        effectiveDate: '1405/08/01',
        issueDate: '',
        draftedOn: '1405/08/01',
        reason: 'annual',
        reasonLabel: 'افزایش سالانه',
        revision: 1,
      ),
    ];

    when(() => repository.listOrders(
          company: 'شرکت تابان',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => orders);
    when(() => repository.getTemplate(company: 'شرکت تابان'))
        .thenAnswer((_) async => {'revision': 1});
    when(() => repository.people(company: 'شرکت تابان'))
        .thenAnswer((_) async => []);

    for (final width in [320.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(createWidget(width: width));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('احکام تغییر حقوق و مزایا'), findsWidgets);
      expect(find.text('＋ حکم تغییر حقوق جدید'), findsOneWidget);
      expect(find.text('علی رضایی'), findsOneWidget);
      expect(find.text('پیش‌نویس'), findsWidgets);
      expect(find.text('اعمال‌نشده'), findsWidgets);
    }
  });

  testWidgets('switching to form view, selecting person, and opening preview',
      (tester) async {
    const person = SalaryChangeOrderPerson(
      name: 'EMP-1',
      displayName: 'احمد شاملو',
      employeeNumber: 'HR-101',
      department: 'امور اداری',
      designation: 'کارشناس اداری',
    );
    const payroll = SalaryChangePayrollResult(
      currency: 'ریال',
      rows: [
        SalaryChangeComparisonRow(
          id: 'base_salary',
          title: 'حقوق پایه',
          period: 'monthly',
          periodLabel: 'ماهانه',
          oldRef: 'payroll.base_salary',
          newRef: 'document.new.base_salary',
          previousAmount: 200000000,
          state: 'available',
        ),
      ],
    );

    when(() => repository.listOrders(
          company: 'شرکت تابان',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تابان'))
        .thenAnswer((_) async => {'revision': 1});
    when(() => repository.people(company: 'شرکت تابان'))
        .thenAnswer((_) async => [person]);
    when(() => repository.payroll(
          company: 'شرکت تابان',
          employee: 'EMP-1',
          effectiveDate: any(named: 'effectiveDate'),
        )).thenAnswer((_) async => payroll);

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(createWidget(width: 390));
    await tester.pumpAndSettle();

    // Tap new order
    await tester.tap(find.text('＋ حکم تغییر حقوق جدید'));
    await tester.pumpAndSettle();

    expect(find.text('صدور حکم تغییر حقوق'), findsWidgets);
    expect(find.text('۱. مشخصات پرسنل'), findsOneWidget);
    expect(find.text('۲. مشخصات تغییر حقوق'), findsOneWidget);
    expect(find.text('۳. مقایسه حقوق و مزایا'), findsOneWidget);

    // Select employee
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('احمد شاملو — HR-101').last);
    await tester.pumpAndSettle();

    final today = DateTime.now().toIso8601String().split('T').first;
    verify(() => repository.payroll(
          company: 'شرکت تابان',
          employee: 'EMP-1',
          effectiveDate: today,
        )).called(1);
    expect(find.text(formatJalaliIso(today)), findsOneWidget);

    // Enter proposed base salary
    final inputs = find.byType(TextFormField);
    expect(inputs, findsWidgets);

    // Preview button
    await tester.scrollUntilVisible(
      find.text('پیش‌نمایش چاپ و ارسال'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('پیش‌نمایش چاپ و ارسال'));
    await tester.pumpAndSettle();

    expect(find.text('پیش‌نویس ـ فاقد اعتبار نهایی'), findsOneWidget);
    expect(find.text('ارسال جهت بررسی و گردش‌کار'), findsOneWidget);
    expect(find.text('جمع ماهانه'), findsOneWidget);
  });

  testWidgets('template builder view displays 6 articles, inline editor and preview tab',
      (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تابان',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تابان'))
        .thenAnswer((_) async => null);
    when(() => repository.people(company: 'شرکت تابان'))
        .thenAnswer((_) async => []);
    when(() => repository.saveTemplate(
          company: 'شرکت تابان',
          revision: any(named: 'revision'),
          template: any(named: 'template'),
        )).thenAnswer((_) async => {'revision': 1});
    when(() => repository.publishTemplate(
          company: 'شرکت تابان',
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => {'revision': 1, 'template': {}});

    await tester.binding.setSurfaceSize(const Size(390, 1800));
    await tester.pumpWidget(createWidget(width: 390));
    await tester.pumpAndSettle();

    // Tap template builder
    await tester.tap(find.text('ویرایش و انتشار قالب حکم'));
    await tester.pumpAndSettle();

    expect(find.text('قالب حکم تغییر حقوق و مزایا'), findsWidgets);
    expect(find.text('ماده ۱: مشخصات پرسنل و مستند تغییر'), findsOneWidget);
    expect(find.text('ماده ۴: اقلام حقوق و مزایای قبلی و جدید'), findsOneWidget);

    // Expand article 1 and test inline edit
    await tester.tap(find.text('ماده ۱: مشخصات پرسنل و مستند تغییر'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش'), findsOneWidget);

    await tester.tap(find.text('ویرایش'));
    await tester.pumpAndSettle();

    expect(find.text('درج فیلد در متن ماده'), findsOneWidget);
    expect(find.text('ذخیره تغییرات'), findsOneWidget);

    // Open field picker drawer
    await tester.tap(find.text('درج فیلد در متن ماده'));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب فیلد موجود جهت درج در ماده'), findsOneWidget);
    expect(find.text('پرسنل'), findsOneWidget);
    expect(find.text('شرکت'), findsOneWidget);
    expect(find.text('حکم'), findsOneWidget);
    expect(find.text('حقوق'), findsOneWidget);

    await tester.tap(find.text('[نام و نام خانوادگی پرسنل]'));
    await tester.pumpAndSettle();

    // Switch to preview tab
    await tester.tap(find.text('پیش‌نمایش سند'));
    await tester.pumpAndSettle();

    expect(find.text('پیش‌نمایش قالب ـ فاقد اعتبار نهایی'), findsOneWidget);
    expect(find.text('چاپ / ذخیره PDF پیش‌نمایش'), findsOneWidget);

    // Switch back to editor tab
    await tester.tap(find.text('بازگشت به ویرایش قالب'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('انتشار نسخه نهایی قالب'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('انتشار نسخه نهایی قالب'), findsOneWidget);

    await tester.tap(find.text('انتشار نسخه نهایی قالب'));
    await tester.pumpAndSettle();

    verify(() => repository.publishTemplate(
          company: 'شرکت تابان',
          revision: any(named: 'revision'),
        )).called(1);
  });

  testWidgets(
      'workflow approval and applying to payroll with stable operation id',
      (tester) async {
    const finalOrder = SalaryChangeOrderDetail(
      name: 'ENTRY-1',
      number: 'SAL-1405-001',
      company: 'شرکت تابان',
      companyName: 'شرکت تابان',
      employee: 'EMP-1',
      employeeName: 'احمد شاملو',
      employeeNumber: 'HR-101',
      status: 'final',
      statusLabel: 'نهایی',
      applicationStatus: 'not_applied',
      applicationStatusLabel: 'اعمال‌نشده',
      effectiveDate: '1405/08/01',
      issueDate: '1405/08/01',
      draftedOn: '1405/08/01',
      reason: 'annual',
      reasonLabel: 'افزایش سالانه',
      description: 'شرح تغییر',
      revision: 2,
      comparisonRows: [
        SalaryChangeComparisonRow(
          id: 'base_salary',
          title: 'حقوق پایه',
          period: 'monthly',
          periodLabel: 'ماهانه',
          oldRef: 'payroll.base_salary',
          newRef: 'document.new.base_salary',
          previousAmount: 200000000,
          newAmount: 250000000,
          difference: 50000000,
          percentChange: 25.0,
          state: 'available',
        ),
      ],
    );

    const summary = SalaryChangeOrderSummary(
      name: 'ENTRY-1',
      number: 'SAL-1405-001',
      employee: 'EMP-1',
      employeeName: 'احمد شاملو',
      status: 'final',
      statusLabel: 'نهایی',
      applicationStatus: 'not_applied',
      applicationStatusLabel: 'اعمال‌نشده',
      effectiveDate: '1405/08/01',
      issueDate: '1405/08/01',
      draftedOn: '1405/08/01',
      reason: 'annual',
      reasonLabel: 'افزایش سالانه',
      revision: 2,
    );

    const appliedOrder = SalaryChangeOrderDetail(
      name: 'ENTRY-1',
      number: 'SAL-1405-001',
      company: 'شرکت تابان',
      companyName: 'شرکت تابان',
      employee: 'EMP-1',
      employeeName: 'احمد شاملو',
      employeeNumber: 'HR-101',
      status: 'final',
      statusLabel: 'نهایی',
      applicationStatus: 'applied',
      applicationStatusLabel: 'اعمال‌شده بر حقوق',
      effectiveDate: '1405/08/01',
      issueDate: '1405/08/01',
      draftedOn: '1405/08/01',
      reason: 'annual',
      reasonLabel: 'افزایش سالانه',
      revision: 2,
    );

    when(() => repository.listOrders(
          company: 'شرکت تابان',
          search: any(named: 'search'),
          status: any(named: 'status'),
          applicationStatus: any(named: 'applicationStatus'),
        )).thenAnswer((_) async => [summary]);
    when(() => repository.getOrder(name: 'ENTRY-1'))
        .thenAnswer((_) async => finalOrder);
    when(() => repository.getTemplate(company: 'شرکت تابان'))
        .thenAnswer((_) async => {'revision': 1});
    when(() => repository.people(company: 'شرکت تابان'))
        .thenAnswer((_) async => []);
    when(() => repository.printOrder(name: 'ENTRY-1'))
        .thenAnswer((_) async => const SalaryChangeOrderPrint(
              html: '<div>print</div>',
              status: 'final',
              number: 'SAL-1405-001',
              draftBanner: false,
            ));
    when(() => repository.applyToPayroll(
          name: 'ENTRY-1',
          operationId: any(named: 'operationId'),
        )).thenAnswer((_) async => appliedOrder);

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(createWidget(width: 390));
    await tester.pumpAndSettle();

    expect(find.text('◉ مشاهده و بازبینی'), findsOneWidget);
    await tester.tap(find.text('◉ مشاهده و بازبینی'));
    await tester.pumpAndSettle();

    expect(find.text('پیش‌نویس ـ فاقد اعتبار نهایی'), findsNothing);
    expect(find.text('اعمال بر سیستم حقوق و دستمزد'), findsOneWidget);

    await tester.tap(find.text('اعمال بر سیستم حقوق و دستمزد'));
    await tester.pumpAndSettle();

    verify(() => repository.applyToPayroll(
          name: 'ENTRY-1',
          operationId: 'salary-change-ENTRY-1',
        )).called(1);
  });
}
