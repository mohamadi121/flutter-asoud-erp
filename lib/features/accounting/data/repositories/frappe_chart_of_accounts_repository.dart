import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class FrappeChartOfAccountsRepository implements ChartOfAccountsRepository {
  const FrappeChartOfAccountsRepository(this._client);
  final FrappeClient _client;

  @override
  Future<List<AccountNode>> getAccounts(String company) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.list_accounts',
      data: {'company': company},
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((item) => _fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<AccountNode> createAccount(String company, AccountNode account,
      {required bool autoCode}) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.create_account',
      data: {
        'company': company,
        'account_name': account.title,
        'level': _levelToApi(account.level),
        'parent_account': account.parentId,
        'account_number': account.code.isEmpty ? null : account.code,
        'auto_code': autoCode ? 1 : 0,
        'root_type': _rootType(account.nature),
        'account_type':
            account.accountType.isEmpty ? null : account.accountType,
      },
    );
    if (response is! Map) return account;
    return _fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<AccountNode> updateAccount(String company, AccountNode account) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.update_account',
      data: {
        'company': company,
        'account': account.id,
        'account_name': account.title,
        'parent_account': account.parentId,
        'disabled': account.isActive ? 0 : 1,
        'root_type': _rootType(account.nature),
        'account_type':
            account.accountType.isEmpty ? null : account.accountType,
      },
    );
    if (response is! Map) return account;
    return _fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<AccountNode>> importAccounts(
      String company, List<Map<String, dynamic>> rows) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.import_accounts',
      data: {'company': company, 'rows': rows},
    );
    if (response is! List) {
      throw const FormatException('Invalid account import response');
    }
    return response
        .whereType<Map>()
        .map((item) => _fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<ChartTemplateRow>> previewTemplate(
      String company, String template) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.preview_chart_template',
      data: {'company': company, 'template': template},
    );
    if (response is! Map || response['rows'] is! List) {
      throw const FormatException('Invalid chart template preview response');
    }
    return (response['rows'] as List).whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      return ChartTemplateRow(
        key: row['key']?.toString() ?? '',
        level: row['level']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        parentKey: row['parent_key']?.toString(),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<AccountNode>> applyTemplate(
      String company, String template) async {
    final response = await _client.callAsoudMethod(
      'asoud_erp.api.v1.account.apply_chart_template',
      data: {'company': company, 'template': template},
    );
    if (response is! List) {
      throw const FormatException('Invalid chart template apply response');
    }
    return response
        .whereType<Map>()
        .map((raw) => _fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  AccountNode _fromJson(Map<String, dynamic> json) => AccountNode(
        id: json['name'] as String? ?? '',
        code: json['account_number']?.toString() ?? '',
        title: json['account_name'] as String? ?? '',
        level: _levelFromApi(json['asoud_level'] as String?),
        parentId: json['parent_account'] as String?,
        nature: _natureFromRootType(json['root_type'] as String?),
        accountType: json['account_type'] as String? ?? '',
      );

  AccountLevel _levelFromApi(String? value) => switch (value) {
        'Group' => AccountLevel.group,
        'General' => AccountLevel.general,
        'Detail' => AccountLevel.detail,
        _ => AccountLevel.ledger,
      };

  String _levelToApi(AccountLevel value) => switch (value) {
        AccountLevel.group => 'Group',
        AccountLevel.general => 'General',
        AccountLevel.ledger => 'Ledger',
        AccountLevel.detail => 'Detail',
      };

  AccountNature _natureFromRootType(String? value) => switch (value) {
        'Liability' || 'Equity' || 'Income' => AccountNature.credit,
        'Asset' || 'Expense' => AccountNature.debit,
        _ => AccountNature.both,
      };

  String _rootType(AccountNature nature) => switch (nature) {
        AccountNature.debit => 'Asset',
        AccountNature.credit => 'Liability',
        AccountNature.both => 'Asset',
      };
}
