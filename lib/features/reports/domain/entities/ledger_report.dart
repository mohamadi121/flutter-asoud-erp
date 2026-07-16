import 'package:equatable/equatable.dart';

class LedgerEntry extends Equatable {
  const LedgerEntry({
    required this.date,
    required this.account,
    required this.voucherType,
    required this.voucherNo,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.party = '',
  });
  final DateTime date;
  final String account;
  final String voucherType;
  final String voucherNo;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String party;
  @override
  List<Object?> get props => [date, account, voucherType, voucherNo, description, debit, credit, balance, party];
}

class LedgerReport extends Equatable {
  const LedgerReport({required this.openingBalance, required this.entries, required this.totalDebit, required this.totalCredit, required this.closingBalance});
  final double openingBalance;
  final List<LedgerEntry> entries;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
  @override
  List<Object?> get props => [openingBalance, entries, totalDebit, totalCredit, closingBalance];
}
