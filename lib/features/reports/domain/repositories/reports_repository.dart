import '../entities/ledger_report.dart';
import '../entities/trial_balance.dart';

abstract interface class ReportsRepository {
  Future<TrialBalanceReport> getTrialBalance({required String company, required DateTime fromDate, required DateTime toDate, String? account});
  Future<LedgerReport> getLedger({required String company, required DateTime fromDate, required DateTime toDate, required String account, String? partyType, String? party});
}
