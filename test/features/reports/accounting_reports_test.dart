import 'package:asoud_erp/features/reports/domain/entities/ledger_report.dart';
import 'package:asoud_erp/features/reports/domain/entities/trial_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trial balance detects equal period turnover', () {
    const totals = TrialBalanceRow(
      account: 'جمع کل',
      openingDebit: 100,
      openingCredit: 100,
      periodDebit: 500,
      periodCredit: 500,
      closingDebit: 600,
      closingCredit: 600,
    );
    expect(const TrialBalanceReport(rows: [], totals: totals).periodIsBalanced, isTrue);
  });

  test('ledger report preserves server closing balance', () {
    final report = LedgerReport(
      openingBalance: 100,
      entries: [
        LedgerEntry(
          date: DateTime(2026, 7, 16),
          account: 'Cash',
          voucherType: 'Journal Entry',
          voucherNo: 'JV-1',
          description: 'دریافت',
          debit: 50,
          credit: 0,
          balance: 150,
        ),
      ],
      totalDebit: 50,
      totalCredit: 0,
      closingBalance: 150,
    );
    expect(report.closingBalance, 150);
  });
}
