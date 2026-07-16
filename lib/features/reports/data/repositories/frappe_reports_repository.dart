import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/ledger_report.dart';
import '../../domain/entities/trial_balance.dart';
import '../../domain/repositories/reports_repository.dart';

class FrappeReportsRepository implements ReportsRepository {
  const FrappeReportsRepository(this._client);
  final FrappeClient _client;

  @override
  Future<TrialBalanceReport> getTrialBalance({required String company, required DateTime fromDate, required DateTime toDate, String? account}) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.report.trial_balance',
      _map,
      data: {'company': company, 'from_date': _date(fromDate), 'to_date': _date(toDate), if (account?.isNotEmpty ?? false) 'account': account},
    );
    final rows = ((response.data['rows'] as List?) ?? const []).map((value) => _trialRow(Map<String, dynamic>.from(value as Map))).toList();
    final totals = _trialRow(Map<String, dynamic>.from(response.data['totals'] as Map), account: 'جمع کل');
    return TrialBalanceReport(rows: rows, totals: totals);
  }

  @override
  Future<LedgerReport> getLedger({required String company, required DateTime fromDate, required DateTime toDate, required String account, String? partyType, String? party}) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.report.general_ledger',
      _map,
      data: {
        'company': company,
        'from_date': _date(fromDate),
        'to_date': _date(toDate),
        'account': account,
        if (partyType?.isNotEmpty ?? false) 'party_type': partyType,
        if (party?.isNotEmpty ?? false) 'party': party,
      },
    );
    final entries = ((response.data['entries'] as List?) ?? const []).map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      return LedgerEntry(
        date: DateTime.tryParse(row['posting_date']?.toString() ?? '') ?? DateTime.now(),
        account: row['account']?.toString() ?? '',
        voucherType: row['voucher_type']?.toString() ?? '',
        voucherNo: row['voucher_no']?.toString() ?? '',
        description: row['remarks']?.toString() ?? '',
        party: row['party']?.toString() ?? '',
        debit: _number(row['debit']),
        credit: _number(row['credit']),
        balance: _number(row['balance']),
      );
    }).toList();
    return LedgerReport(
      openingBalance: _number(response.data['opening_balance']),
      entries: entries,
      totalDebit: _number(response.data['total_debit']),
      totalCredit: _number(response.data['total_credit']),
      closingBalance: _number(response.data['closing_balance']),
    );
  }

  static Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value! as Map);
  static double _number(Object? value) => (value as num?)?.toDouble() ?? double.tryParse(value?.toString() ?? '') ?? 0;
  static String _date(DateTime value) => value.toIso8601String().split('T').first;
  static TrialBalanceRow _trialRow(Map<String, dynamic> row, {String? account}) => TrialBalanceRow(
        account: account ?? row['account']?.toString() ?? '',
        openingDebit: _number(row['opening_debit']),
        openingCredit: _number(row['opening_credit']),
        periodDebit: _number(row['period_debit']),
        periodCredit: _number(row['period_credit']),
        closingDebit: _number(row['closing_debit']),
        closingCredit: _number(row['closing_credit']),
      );
}
