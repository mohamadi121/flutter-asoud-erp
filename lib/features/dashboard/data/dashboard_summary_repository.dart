import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';

/// Reads the home and settings dashboard figures from
/// `asoud_erp.api.v1.dashboard`.
///
/// A figure the current user may not read comes back as `null` from the server
/// (never a false `0`), so the models keep every money/count value nullable and
/// the UI hides the cards it cannot fill.
class DashboardSummaryRepository {
  const DashboardSummaryRepository(this.client);

  final FrappeApiClient client;

  static const _prefix = 'asoud_erp.api.v1.dashboard';

  Future<HomeSummary> loadHome(String company) async {
    final data = await _call('get_home_summary', {'company': company});
    return HomeSummary.fromJson(data);
  }

  Future<SystemSummary> loadSystem() async {
    final data = await _call('get_system_summary');
    return SystemSummary.fromJson(data);
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? data,
  ]) async {
    final response = await client
        .callMethod('$_prefix.$method', data: data)
        .timeout(const Duration(seconds: 15));
    final envelope = response['message'];
    if (envelope is! Map ||
        envelope['meta'] is! Map ||
        (envelope['meta'] as Map)['api_version'] != 'v1') {
      throw const ApiException.protocol();
    }
    return AsoudApiResponse<Map<String, dynamic>>.parse(
      Map<String, dynamic>.from(envelope),
      (value) => Map<String, dynamic>.from(value as Map),
    ).data;
  }
}

num? _toNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

int? _toInt(Object? value) {
  final num = _toNum(value);
  return num?.toInt();
}

String? _toStr(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// One bank or cash account balance inside [HomeSummary.bankAndCash].
class BankAccountBalance {
  const BankAccountBalance({
    required this.account,
    required this.accountName,
    required this.accountType,
    required this.balance,
  });

  factory BankAccountBalance.fromJson(Map<String, dynamic> json) =>
      BankAccountBalance(
        account: _toStr(json['account']) ?? '',
        accountName: _toStr(json['account_name']) ?? '',
        accountType: _toStr(json['account_type']) ?? '',
        balance: _toNum(json['balance']),
      );

  final String account;
  final String accountName;
  final String accountType;
  final num? balance;
}

/// `bank_and_cash` of the home summary; `null` when the user cannot read
/// `Account`/`GL Entry`.
class BankAndCash {
  const BankAndCash({required this.total, required this.accounts});

  factory BankAndCash.fromJson(Map<String, dynamic> json) => BankAndCash(
        total: _toNum(json['total']),
        accounts: (json['accounts'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => BankAccountBalance.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final num? total;
  final List<BankAccountBalance> accounts;

  int get accountCount => accounts.length;
}

/// `open_documents` of the home summary. Each count is `null` when the user
/// cannot read that DocType; [total] sums only the figures that are readable.
class OpenDocuments {
  const OpenDocuments({
    required this.total,
    this.unpaidSalesInvoices,
    this.unpaidPurchaseInvoices,
    this.draftSalesInvoices,
    this.draftPaymentEntries,
    this.draftJournalEntries,
    this.pendingMaterialRequests,
    this.myOpenTasks,
  });

  factory OpenDocuments.fromJson(Map<String, dynamic> json) => OpenDocuments(
        total: _toInt(json['total']),
        unpaidSalesInvoices: _toInt(json['unpaid_sales_invoices']),
        unpaidPurchaseInvoices: _toInt(json['unpaid_purchase_invoices']),
        draftSalesInvoices: _toInt(json['draft_sales_invoices']),
        draftPaymentEntries: _toInt(json['draft_payment_entries']),
        draftJournalEntries: _toInt(json['draft_journal_entries']),
        pendingMaterialRequests: _toInt(json['pending_material_requests']),
        myOpenTasks: _toInt(json['my_open_tasks']),
      );

  final int? total;
  final int? unpaidSalesInvoices;
  final int? unpaidPurchaseInvoices;
  final int? draftSalesInvoices;
  final int? draftPaymentEntries;
  final int? draftJournalEntries;
  final int? pendingMaterialRequests;
  final int? myOpenTasks;
}

/// Figures of `get_home_summary` for one company.
class HomeSummary {
  const HomeSummary({
    required this.company,
    this.date,
    this.currency,
    this.todayReceipts,
    this.todayPayments,
    this.todaySales,
    this.bankAndCash,
    this.openDocuments,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        company: _toStr(json['company']) ?? '',
        date: _toStr(json['date']),
        currency: _toStr(json['currency']),
        todayReceipts: _toNum(json['today_receipts']),
        todayPayments: _toNum(json['today_payments']),
        todaySales: _toNum(json['today_sales']),
        bankAndCash: json['bank_and_cash'] is Map
            ? BankAndCash.fromJson(
                Map<String, dynamic>.from(json['bank_and_cash'] as Map))
            : null,
        openDocuments: json['open_documents'] is Map
            ? OpenDocuments.fromJson(
                Map<String, dynamic>.from(json['open_documents'] as Map))
            : null,
      );

  final String company;
  final String? date;
  final String? currency;
  final num? todayReceipts;
  final num? todayPayments;
  final num? todaySales;
  final BankAndCash? bankAndCash;
  final OpenDocuments? openDocuments;
}

/// Site health from `get_system_summary` (System Manager only).
class SystemSummary {
  const SystemSummary({
    required this.usersTotal,
    required this.usersActive,
    required this.usersOnline,
    this.onlineWindowMinutes,
    this.storageUsedBytes,
    this.storageQuotaBytes,
    this.pendingWorkflowTasks,
    this.errorsLast24h,
    this.syncLastCompletedOn,
    this.syncStuckRequests,
    this.schedulerEnabled,
  });

  factory SystemSummary.fromJson(Map<String, dynamic> json) {
    final users = json['users'] is Map
        ? Map<String, dynamic>.from(json['users'] as Map)
        : const <String, dynamic>{};
    final storage = json['storage'] is Map
        ? Map<String, dynamic>.from(json['storage'] as Map)
        : const <String, dynamic>{};
    final sync = json['sync'] is Map
        ? Map<String, dynamic>.from(json['sync'] as Map)
        : const <String, dynamic>{};
    return SystemSummary(
      usersTotal: _toInt(users['total']),
      usersActive: _toInt(users['active']),
      usersOnline: _toInt(users['online']),
      onlineWindowMinutes: _toInt(users['online_window_minutes']),
      storageUsedBytes: _toInt(storage['used_bytes']),
      storageQuotaBytes: _toInt(storage['quota_bytes']),
      pendingWorkflowTasks: _toInt(json['pending_workflow_tasks']),
      errorsLast24h: _toInt(json['errors_last_24h']),
      syncLastCompletedOn: _toStr(sync['last_completed_on']),
      syncStuckRequests: _toInt(sync['stuck_requests']),
      schedulerEnabled: json['scheduler_enabled'] is bool
          ? json['scheduler_enabled'] as bool
          : null,
    );
  }

  final int? usersTotal;
  final int? usersActive;
  final int? usersOnline;
  final int? onlineWindowMinutes;
  final int? storageUsedBytes;
  final int? storageQuotaBytes;
  final int? pendingWorkflowTasks;
  final int? errorsLast24h;
  final String? syncLastCompletedOn;
  final int? syncStuckRequests;
  final bool? schedulerEnabled;
}
