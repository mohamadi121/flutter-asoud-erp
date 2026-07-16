import 'package:equatable/equatable.dart';

class TrialBalanceRow extends Equatable {
  const TrialBalanceRow({
    required this.account,
    required this.openingDebit,
    required this.openingCredit,
    required this.periodDebit,
    required this.periodCredit,
    required this.closingDebit,
    required this.closingCredit,
  });
  final String account;
  final double openingDebit;
  final double openingCredit;
  final double periodDebit;
  final double periodCredit;
  final double closingDebit;
  final double closingCredit;

  @override
  List<Object?> get props => [account, openingDebit, openingCredit, periodDebit, periodCredit, closingDebit, closingCredit];
}

class TrialBalanceReport extends Equatable {
  const TrialBalanceReport({required this.rows, required this.totals});
  final List<TrialBalanceRow> rows;
  final TrialBalanceRow totals;
  bool get periodIsBalanced => (totals.periodDebit - totals.periodCredit).abs() < .01;
  @override
  List<Object?> get props => [rows, totals];
}
