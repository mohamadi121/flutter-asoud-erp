import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class FrappeChartOfAccountsRepository implements ChartOfAccountsRepository {
  const FrappeChartOfAccountsRepository(this._client, {required this.company});
  final FrappeClient _client;
  final String company;

  @override
  Future<List<AccountNode>> getAccounts() async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.account.list_accounts',
      (value) => (value as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      data: {'company': company},
    );
    return _buildTree(response.data);
  }

  @override
  Future<String> previewNextCode(
    AccountLevel level, {
    String? parentId,
  }) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.account.preview_next_code',
      (value) => Map<String, dynamic>.from(value! as Map),
      data: {
        'company': company,
        'level': _levelName(level),
        if (parentId != null) 'parent_account': parentId,
      },
    );
    return response.data['account_number']?.toString() ?? '';
  }

  @override
  Future<AccountNode> createAccount(AccountNode account) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.account.create_account',
      (value) => Map<String, dynamic>.from(value! as Map),
      data: {
        'company': company,
        'account_name': account.title,
        'level': _levelName(account.level),
        if (account.parentId != null) 'parent_account': account.parentId,
        if (account.code.isNotEmpty) 'account_number': account.code,
        'auto_code': account.code.isEmpty ? 1 : 0,
        'root_type': _rootType(account.nature),
      },
    );
    return _fromJson(response.data);
  }

  @override
  Future<AccountNode> updateAccount(AccountNode account) async {
    final response = await _client.updateResource('Account', account.id, _toJson(account));
    return response['data'] is Map<String, dynamic> ? _fromJson(response['data'] as Map<String, dynamic>) : account;
  }

  AccountNode _fromJson(Map<String, dynamic> json) => AccountNode(
        id: json['name'] as String? ?? '',
        code: json['account_number']?.toString() ?? '',
        title: json['account_name'] as String? ?? '',
        level: _levelFromName(json['asoud_level']?.toString()),
        parentId: json['parent_account'] as String?,
        isActive: json['disabled'] != 1,
        nature: _natureFromRootType(json['root_type'] as String?),
      );

  List<AccountNode> _buildTree(List<Map<String, dynamic>> rows) {
    final childrenByParent = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final parent = row['parent_account']?.toString() ?? '';
      childrenByParent.putIfAbsent(parent, () => []).add(row);
    }

    AccountNode build(Map<String, dynamic> row) {
      final id = row['name']?.toString() ?? '';
      final node = _fromJson(row);
      return AccountNode(
        id: node.id,
        code: node.code,
        title: node.title,
        level: node.level,
        parentId: node.parentId,
        isActive: node.isActive,
        nature: node.nature,
        children: (childrenByParent[id] ?? const []).map(build).toList(),
      );
    }

    final knownNames = rows.map((row) => row['name']?.toString()).toSet();
    return rows
        .where((row) => !knownNames.contains(row['parent_account']?.toString()))
        .map(build)
        .toList();
  }

  AccountLevel _levelFromName(String? value) => switch (value) {
        'Group' => AccountLevel.group,
        'General' => AccountLevel.general,
        _ => AccountLevel.ledger,
      };

  String _levelName(AccountLevel level) => switch (level) {
        AccountLevel.group => 'Group',
        AccountLevel.general => 'General',
        AccountLevel.ledger => 'Ledger',
        AccountLevel.detail => 'Ledger',
      };

  Map<String, dynamic> _toJson(AccountNode account) => {
        'account_name': account.title,
        'account_number': account.code,
        'parent_account': account.parentId,
        'is_group': account.level == AccountLevel.group || account.level == AccountLevel.general ? 1 : 0,
        'disabled': account.isActive ? 0 : 1,
        'root_type': _rootType(account.nature),
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
