import 'dart:convert';

import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/accounting_voucher.dart';
import '../../domain/repositories/vouchers_repository.dart';

class FrappeVouchersRepository implements VouchersRepository {
  const FrappeVouchersRepository(this._client);
  final FrappeClient _client;

  @override
  Future<List<AccountingVoucher>> getVouchers(String company, {VoucherStatus? status, String? search}) async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.voucher.list_vouchers',
      _list,
      data: {'company': company, if (status != null) 'status': _statusToApi(status), if (search?.isNotEmpty ?? false) 'search': search},
    );
    return response.data.map(_fromJson).toList();
  }

  @override
  Future<AccountingVoucher> saveVoucher(AccountingVoucher voucher) => _call(
        'asoud_erp.api.v1.voucher.save_voucher',
        {
          if (voucher.id.isNotEmpty) 'name': voucher.id,
          'company': voucher.company,
          'posting_date': voucher.postingDate.toIso8601String().split('T').first,
          'description': voucher.description,
          'lines': jsonEncode(voucher.lines.map((row) => {
                'account': row.account,
                'floating_detail': row.floatingDetail,
                'description': row.description,
                'debit': row.debit,
                'credit': row.credit,
              }).toList()),
        },
      );

  @override
  Future<AccountingVoucher> submitForApproval(String id) => _call('asoud_erp.api.v1.voucher.submit_for_approval', {'name': id});

  @override
  Future<AccountingVoucher> approve(String id) => _call('asoud_erp.api.v1.voucher.approve_voucher', {'name': id});

  @override
  Future<AccountingVoucher> reject(String id, String reason) => _call('asoud_erp.api.v1.voucher.reject_voucher', {'name': id, 'reason': reason});

  Future<AccountingVoucher> _call(String method, Map<String, dynamic> data) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(method, _map, data: data);
    return _fromJson(response.data);
  }

  static List<Map<String, dynamic>> _list(Object? value) => (value as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  static Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value! as Map);

  static AccountingVoucher _fromJson(Map<String, dynamic> row) => AccountingVoucher(
        id: row['name']?.toString() ?? '',
        company: row['company']?.toString() ?? '',
        postingDate: DateTime.tryParse(row['posting_date']?.toString() ?? '') ?? DateTime.now(),
        description: row['description']?.toString() ?? '',
        status: _statusFromApi(row['status']?.toString()),
        rejectionReason: row['rejection_reason']?.toString() ?? '',
        journalEntry: row['journal_entry']?.toString() ?? '',
        lines: ((row['lines'] as List?) ?? const []).map((item) {
          final value = Map<String, dynamic>.from(item as Map);
          return VoucherLine(
            account: value['account']?.toString() ?? '',
            floatingDetail: value['floating_detail']?.toString() ?? '',
            description: value['description']?.toString() ?? '',
            debit: (value['debit'] as num?)?.toDouble() ?? 0,
            credit: (value['credit'] as num?)?.toDouble() ?? 0,
          );
        }).toList(),
      );

  static String _statusToApi(VoucherStatus value) => switch (value) {
        VoucherStatus.draft => 'Draft',
        VoucherStatus.pendingApproval => 'Pending Approval',
        VoucherStatus.approved => 'Approved',
        VoucherStatus.rejected => 'Rejected',
      };

  static VoucherStatus _statusFromApi(String? value) => switch (value) {
        'Pending Approval' => VoucherStatus.pendingApproval,
        'Approved' => VoucherStatus.approved,
        'Rejected' => VoucherStatus.rejected,
        _ => VoucherStatus.draft,
      };
}
