import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/table_field.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/table_row_page.dart';

class _FakeClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'admin@asoud.local',
        fullName: 'مدیر سیستم',
        roles: ['System Manager'],
        company: 'شرکت نمونه آسود',
      );
}

Widget _wrap(Widget child, [double width = 360]) => MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = FormRepository(_FakeClient(), 'شرکت نمونه آسود');

  final testColumns = <FormMap>[
    {
      'key': 'name',
      'label': 'نام کالا',
      'type': 'Text',
      'required': true,
    },
    {
      'key': 'qty',
      'label': 'تعداد',
      'type': 'Integer',
      'required': true,
    },
    {
      'key': 'rate',
      'label': 'قیمت واحد',
      'type': 'Money',
      'required': true,
    },
    {
      'key': 'amount',
      'label': 'مبلغ ردیف',
      'type': 'Formula',
      'formula': {
        'op': 'multiply',
        'inputs': ['qty', 'rate'],
      },
    },
  ];

  final testTableField = <String, dynamic>{
    'key': 'items',
    'label': 'اقلام درخواست خرید',
    'type': 'Table',
    'columns': testColumns,
    'max_rows': 5,
    'min_rows': 2,
  };

  testWidgets('رندر فیلد جدول تکرارشونده و کارت‌های ردیف و جمع کل',
      (tester) async {
    final rows = [
      {
        'name': 'کاغذ A4',
        'qty': '2',
        'rate': '150000',
        'amount': '300000',
      },
      {
        'name': 'خودکار آبی',
        'qty': '10',
        'rate': '25000',
        'amount': '250000',
      },
    ];

    await tester.pumpWidget(_wrap(
      buildTableField(
        f: testTableField,
        value: rows,
        label: 'اقلام درخواست خرید',
        editable: true,
        snapshot: false,
        repository: repo,
        formName: null,
        onChanged: (_) {},
      )!,
    ));
    await tester.pumpAndSettle();

    // Verify title and counts
    expect(find.text('اقلام درخواست خرید'), findsOneWidget);
    expect(find.text('۲ ردیف · ۴ ستون'), findsOneWidget);

    // Verify row cards
    expect(find.text('۱. کاغذ A4'), findsOneWidget);
    expect(find.text('تعداد: ۲ · قیمت واحد: ۱۵۰٬۰۰۰'), findsOneWidget);
    expect(find.text('۳۰۰٬۰۰۰ تومان'), findsOneWidget);

    expect(find.text('۲. خودکار آبی'), findsOneWidget);
    expect(find.text('تعداد: ۱۰ · قیمت واحد: ۲۵٬۰۰۰'), findsOneWidget);
    expect(find.text('۲۵۰٬۰۰۰ تومان'), findsOneWidget);

    // Verify grand total (300,000 + 250,000 = 550,000)
    expect(find.text('جمع کل'), findsOneWidget);
    expect(find.text('۵۵۰٬۰۰۰ تومان'), findsOneWidget);
  });

  testWidgets('حذف ردیف نیازمند تأیید در دیالوگ است', (tester) async {
    final rows = [
      {
        'name': 'کاغذ A4',
        'qty': '2',
        'rate': '150000',
        'amount': '300000',
      },
    ];

    List<dynamic>? updatedRows;

    await tester.pumpWidget(_wrap(
      buildTableField(
        f: testTableField,
        value: rows,
        label: 'اقلام درخواست خرید',
        editable: true,
        snapshot: false,
        repository: repo,
        formName: null,
        onChanged: (val) => updatedRows = val as List?,
      )!,
    ));
    await tester.pumpAndSettle();

    // Tap delete icon
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('حذف ردیف'), findsOneWidget);
    expect(find.text('آیا از حذف ردیف ۱ اطمینان دارید؟'), findsOneWidget);

    // Tap confirm in dialog
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(updatedRows, isNotNull);
    expect(updatedRows!.isEmpty, isTrue);
  });

  testWidgets('رسیدن به حداکثر ردیف دکمه افزودن را غیرفعال و پیام نمایش می‌دهد',
      (tester) async {
    final rows = List.generate(
      5,
      (i) => {
        'name': 'کالا ${i + 1}',
        'qty': '1',
        'rate': '1000',
        'amount': '1000',
      },
    );

    await tester.pumpWidget(_wrap(
      buildTableField(
        f: testTableField,
        value: rows,
        label: 'اقلام درخواست خرید',
        editable: true,
        snapshot: false,
        repository: repo,
        formName: null,
        onChanged: (_) {},
      )!,
    ));
    await tester.pumpAndSettle();

    expect(find.text('حداکثر تعداد ردیف (۵) تکمیل شده است.'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'افزودن ردیف'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('رندر فیلد جدول تکرارشونده در عرض‌های ۳۲۰ و ۳۶۰ بدون خطا و سرریز',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      final rows = [
        {
          'name': 'کالای بسیار طولانی با عنوان کامل و تست عرض',
          'qty': '100',
          'rate': '12500000',
          'amount': '1250000000',
        },
      ];

      await tester.pumpWidget(_wrap(
        buildTableField(
          f: testTableField,
          value: rows,
          label: 'اقلام درخواست خرید',
          editable: true,
          snapshot: false,
          repository: repo,
          formName: null,
          onChanged: (_) {},
        )!,
        width,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('اقلام درخواست خرید'), findsOneWidget);
    }
  });

  testWidgets('صفحه افزودن و ویرایش ردیف اعتبارسنجی و محاسبه آنی انجام می‌دهد',
      (tester) async {
    FormMap? savedRow;

    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                savedRow = await Navigator.push<FormMap>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TableRowPage(
                      tableTitle: 'اقلام درخواست خرید',
                      columns: testColumns,
                      row: const {},
                      repository: repo,
                      isNew: true,
                    ),
                  ),
                );
              },
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open row page
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();

    expect(find.text('افزودن ردیف'), findsOneWidget);
    expect(find.text('اقلام درخواست خرید'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);
    expect(find.text('ثبت ردیف'), findsOneWidget);

    // Try saving empty (should show validation error)
    await tester.tap(find.text('ثبت ردیف'));
    await tester.pumpAndSettle();
    expect(savedRow, isNull);
    expect(find.text('تکمیل این فیلد الزامی است.'), findsWidgets);

    // Fill inputs
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نام کالا *'),
      'موس بی‌سیم',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تعداد *'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'قیمت واحد *'),
      '200000',
    );
    await tester.pumpAndSettle();

    // Formula calculation must update live (3 * 200,000 = 600,000)
    expect(find.text('۶۰۰٬۰۰۰ تومان'), findsOneWidget);

    // Now submit
    await tester.tap(find.text('ثبت ردیف'));
    await tester.pumpAndSettle();

    expect(savedRow, isNotNull);
    expect(savedRow!['name'], 'موس بی‌سیم');
    expect(savedRow!['qty'], '3');
    expect(savedRow!['rate'], '200000');
    expect(savedRow!['amount'], '600000.00');
  });
}
