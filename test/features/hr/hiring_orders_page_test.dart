import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/features/hr/data/hiring_order_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hiring_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements HiringOrderRepository {}

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
    when(() => repository.payrollCatalog(company: 'شرکت تست'))
        .thenAnswer((_) async => [
              {'field_id': 'base', 'label': 'حقوق پایه (قرارداد)', 'type': 'Currency', 'group': 'حقوق'},
              {'field_id': 'variable', 'label': 'مزایای متغیر (قرارداد)', 'type': 'Currency', 'group': 'مزایا'},
            ]);
  });

  Widget createWidget({required double width, Capabilities? capabilities}) {
    return MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: child!,
        ),
      ),
      home: HiringOrdersPage(
        company: 'شرکت تست',
        repository: repository,
        capabilities: capabilities,
      ),
    );
  }

  testWidgets('renders hiring orders list at 320, 390 and 430 px without overflow',
      (tester) async {
    const orders = [
      HiringOrderSummary(
        name: 'ORD-01',
        number: 'ORD-1405-001',
        employee: 'HR-101',
        employeeName: 'علی رضایی',
        status: 'draft',
        statusLabel: 'پیش‌نویس',
        effectiveDate: '1405/08/01',
        issueDate: '',
        draftedOn: '1405/08/01',
        revision: 1,
      ),
    ];

    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => orders);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => {'revision': 1});
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => []);

    for (final width in [320.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(createWidget(width: width));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('احکام استخدام'), findsWidgets);
      expect(find.text('＋ حکم جدید'), findsOneWidget);
      expect(find.text('علی رضایی'), findsOneWidget);
      expect(find.text('پیش‌نویس'), findsOneWidget);
    }
  });

  testWidgets('tapping ＋ حکم جدید switches to form view and allows preview',
      (tester) async {
    const person = HiringOrderPerson(
      name: 'EMP-1',
      displayName: 'محمد محمدی',
      employeeNumber: 'HR-102',
      department: 'اداری',
      designation: 'کارشناس اداری',
    );
    const payroll = HiringOrderPayroll(
      currency: 'ریال',
      monthlyTotal: 225000000,
      rows: [
        HiringOrderPayrollRow(
          id: 'base_salary',
          title: 'حقوق پایه',
          period: 'monthly',
          amount: 225000000,
          state: 'available',
          message: '',
        ),
      ],
    );

    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => {'revision': 1});
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => [person]);
    when(() => repository.payroll(
          company: 'شرکت تست',
          employee: 'EMP-1',
          effectiveDate: any(named: 'effectiveDate'),
        )).thenAnswer((_) async => payroll);

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(createWidget(width: 390));
    await tester.pumpAndSettle();

    // Tap new order
    await tester.tap(find.text('＋ حکم جدید'));
    await tester.pumpAndSettle();

    expect(find.text('صدور حکم استخدام'), findsWidgets);
    expect(find.text('۱. مشخصات پرسنل'), findsOneWidget);
    expect(find.text('۲. مشخصات حکم'), findsOneWidget);
    expect(find.text('۳. حقوق و مزایا'), findsOneWidget);

    // Select employee from dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('محمد محمدی — HR-۱۰۲').last);
    await tester.pumpAndSettle();

    // Enter location
    await tester.enterText(
        find.widgetWithText(TextFormField, 'محل خدمت *'), 'دفتر مرکزی');
    await tester.pumpAndSettle();

    // Scroll to preview button and tap
    await tester.scrollUntilVisible(
      find.text('◉ بازبینی و پیش‌نمایش چاپ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('◉ بازبینی و پیش‌نمایش چاپ'));
    await tester.pumpAndSettle();

    expect(find.text('پیش‌نویس ـ فاقد اعتبار نهایی'), findsOneWidget);
    expect(find.text('چاپ حکم'), findsOneWidget);
    expect(find.text('جمع مبالغ ماهانه'), findsOneWidget);
  });

  testWidgets('template builder view displays editable articles, inline editor and publish button',
      (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => null);
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => []);
    when(() => repository.saveTemplate(
          company: 'شرکت تست',
          revision: any(named: 'revision'),
          template: any(named: 'template'),
        )).thenAnswer((_) async => {'revision': 1});
    when(() => repository.publishTemplate(
          company: 'شرکت تست',
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => {'revision': 1, 'template': {}});

    await tester.binding.setSurfaceSize(const Size(390, 1800));
    await tester.pumpWidget(createWidget(width: 390));
    await tester.pumpAndSettle();

    // Tap template builder
    await tester.tap(find.text('قالب حکم استخدام'));
    await tester.pumpAndSettle();

    expect(find.text('قالب پیش‌فرض حکم استخدام'), findsOneWidget);
    expect(find.text('ماده ۱: مشخصات پرسنل'), findsOneWidget);
    expect(find.text('افزودن قلم حقوق'), findsOneWidget);
    expect(find.text('انتشار و ذخیره نسخه نهایی قالب'), findsOneWidget);

    // Expand article 1 and click edit
    await tester.tap(find.text('ماده ۱: مشخصات پرسنل'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش'), findsOneWidget);

    await tester.tap(find.text('ویرایش'));
    await tester.pumpAndSettle();

    expect(find.text('درج فیلد در متن ماده'), findsOneWidget);
    expect(find.text('ذخیره تغییرات'), findsOneWidget);

    // Tap field drawer
    await tester.tap(find.text('درج فیلد در متن ماده'));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب فیلد موجود جهت درج در ماده'), findsOneWidget);
    expect(find.text('پرسنل'), findsOneWidget);
    expect(find.text('شرکت'), findsOneWidget);
    expect(find.text('قرارداد'), findsOneWidget);
    expect(find.text('حقوق'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.text('[نام و نام خانوادگی پرسنل]'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('انتشار و ذخیره نسخه نهایی قالب'));
    await tester.pumpAndSettle();

    verify(() => repository.publishTemplate(
          company: 'شرکت تست',
          revision: any(named: 'revision'),
        )).called(1);
  });

  testWidgets('hides template builder button for non-designer HR user',
      (tester) async {
    when(() => repository.listOrders(
          company: 'شرکت تست',
          search: any(named: 'search'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => []);
    when(() => repository.getTemplate(company: 'شرکت تست'))
        .thenAnswer((_) async => null);
    when(() => repository.people(company: 'شرکت تست'))
        .thenAnswer((_) async => []);

    final hrUserCaps = Capabilities.fromRoles(const ['HR User']);

    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(createWidget(width: 390, capabilities: hrUserCaps));
    await tester.pumpAndSettle();

    expect(find.text('＋ حکم جدید'), findsOneWidget);
    expect(find.text('قالب حکم استخدام'), findsNothing);
  });
}
