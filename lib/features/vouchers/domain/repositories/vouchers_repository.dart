import '../entities/accounting_voucher.dart';

abstract interface class VouchersRepository {
  Future<List<AccountingVoucher>> getVouchers(String company, {VoucherStatus? status, String? search});
  Future<AccountingVoucher> saveVoucher(AccountingVoucher voucher);
  Future<AccountingVoucher> submitForApproval(String id);
  Future<AccountingVoucher> approve(String id);
  Future<AccountingVoucher> reject(String id, String reason);
}
