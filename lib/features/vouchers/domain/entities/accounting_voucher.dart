import 'package:equatable/equatable.dart';

enum VoucherStatus { draft, pendingApproval, approved, rejected }

class VoucherLine extends Equatable {
  const VoucherLine({required this.account, this.floatingDetail = '', this.description = '', this.debit = 0, this.credit = 0});
  final String account;
  final String floatingDetail;
  final String description;
  final double debit;
  final double credit;

  bool get isValid => account.trim().isNotEmpty && ((debit > 0) != (credit > 0));

  @override
  List<Object?> get props => [account, floatingDetail, description, debit, credit];
}

class AccountingVoucher extends Equatable {
  const AccountingVoucher({
    this.id = '',
    required this.company,
    required this.postingDate,
    required this.description,
    this.status = VoucherStatus.draft,
    this.lines = const [],
    this.rejectionReason = '',
    this.journalEntry = '',
  });
  final String id;
  final String company;
  final DateTime postingDate;
  final String description;
  final VoucherStatus status;
  final List<VoucherLine> lines;
  final String rejectionReason;
  final String journalEntry;

  double get totalDebit => lines.fold(0, (sum, row) => sum + row.debit);
  double get totalCredit => lines.fold(0, (sum, row) => sum + row.credit);
  bool get isBalanced => lines.length >= 2 && totalDebit > 0 && (totalDebit - totalCredit).abs() < .01;
  bool get isValid => company.isNotEmpty && description.trim().isNotEmpty && isBalanced && lines.every((row) => row.isValid);

  @override
  List<Object?> get props => [id, company, postingDate, description, status, lines, rejectionReason, journalEntry];
}
