import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/features/vouchers/domain/entities/accounting_voucher.dart';

void main() {
  test('balanced voucher is valid', () {
    final voucher = AccountingVoucher(
      company: 'ASOUD',
      postingDate: DateTime(2026, 7, 16),
      description: 'فروش نقدی',
      lines: const [
        VoucherLine(account: 'Cash', debit: 1000000),
        VoucherLine(account: 'Sales', credit: 1000000),
      ],
    );
    expect(voucher.isBalanced, isTrue);
    expect(voucher.isValid, isTrue);
  });

  test('unbalanced voucher is invalid', () {
    final voucher = AccountingVoucher(
      company: 'ASOUD',
      postingDate: DateTime(2026, 7, 16),
      description: 'سند نامتوازن',
      lines: const [
        VoucherLine(account: 'Cash', debit: 1000000),
        VoucherLine(account: 'Sales', credit: 900000),
      ],
    );
    expect(voucher.isBalanced, isFalse);
    expect(voucher.isValid, isFalse);
  });
}
