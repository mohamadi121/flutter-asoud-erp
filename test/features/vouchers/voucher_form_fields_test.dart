import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/vouchers/domain/entities/accounting_voucher.dart';
import 'package:asoud_erp/features/vouchers/domain/repositories/vouchers_repository.dart';
import 'package:asoud_erp/features/vouchers/presentation/pages/voucher_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVouchers implements VouchersRepository {
  AccountingVoucher? saved;
  @override
  Future<AccountingVoucher> saveVoucher(AccountingVoucher voucher) async {
    saved = voucher;
    return voucher;
  }

  @override
  Future<AccountingVoucher> submitForApproval(String id) async => saved!;

  @override
  Future<AccountingVoucher> approve(String id) async => saved!;

  @override
  Future<AccountingVoucher> reject(String id, String reason) async => saved!;

  @override
  Future<List<AccountingVoucher>> getVouchers(String company,
          {VoucherStatus? status, String? search}) async =>
      const [];
}

AccountingVoucher _voucher() => AccountingVoucher(
      company: 'شرکت نمونه',
      postingDate: DateTime(2026, 7, 16),
      description: '',
      lines: const [
        VoucherLine(account: 'نقد'),
        VoucherLine(account: 'فروش'),
      ],
    );

Future<void> _pump(WidgetTester tester, _FakeVouchers repository) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      // Pushed so the success pop has a route to return to.
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VoucherFormPage(
                      repository: repository, voucher: _voucher()))),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('voucher form uses the shared AppTextField for every field',
      (tester) async {
    await _pump(tester, _FakeVouchers());

    expect(find.byType(AppTextField), findsWidgets);
    expect(find.text('شرح سند *'), findsOneWidget);
    // One account field per voucher line (the fixture has two).
    expect(find.text('حساب معین/تفصیلی *'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'voucher form saves the typed description and normalises Persian digits',
      (tester) async {
    final repository = _FakeVouchers();
    await _pump(tester, repository);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'شرح سند *'), 'فروش نقدی');
    // Persian digits: the parser must normalise them to 1000, otherwise the
    // voucher stays unbalanced and the save button never enables.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'بدهکار').first, '۱۰۰۰');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'بستانکار').last, '۱۰۰۰');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ذخیره پیش‌نویس'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.description, 'فروش نقدی');
    expect(repository.saved!.lines.first.debit, 1000.0);
    expect(repository.saved!.lines.last.credit, 1000.0);
    expect(repository.saved!.isBalanced, isTrue);
  });
}
