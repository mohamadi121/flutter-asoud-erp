import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class FrappeChartOfAccountsRepository implements ChartOfAccountsRepository {
  const FrappeChartOfAccountsRepository(this._client);
  final FrappeClient _client;

  @override
  Future<List<AccountNode>> getAccounts() async {
    final response = await _client.callMethod(
      'frappe.client.get_list',
      data: {
        'doctype': 'Account',
        'fields': [
          'name',
          'account_number',
          'account_name',
          'parent_account',
          'is_group'
        ],
        'order_by': 'account_number asc',
        'limit_page_length': 500,
      },
    );
    final message = response['message'];
    if (message is! List) return const [];
    return message.whereType<Map<String, dynamic>>().map(_fromJson).toList();
  }

  @override
  Future<AccountNode> createAccount(AccountNode account) async {
    final response = await _client.createResource('Account', _toJson(account));
    return response['data'] is Map<String, dynamic>
        ? _fromJson(response['data'] as Map<String, dynamic>)
        : account;
  }

  @override
  Future<AccountNode> updateAccount(AccountNode account) async {
    final response =
        await _client.updateResource('Account', account.id, _toJson(account));
    return response['data'] is Map<String, dynamic>
        ? _fromJson(response['data'] as Map<String, dynamic>)
        : account;
  }

  AccountNode _fromJson(Map<String, dynamic> json) => AccountNode(
        id: json['name'] as String? ?? '',
        code: json['account_number']?.toString() ?? '',
        title: json['account_name'] as String? ?? '',
        level: json['is_group'] == 1 ? AccountLevel.group : AccountLevel.ledger,
        parentId: json['parent_account'] as String?,
        nature: _natureFromRootType(json['root_type'] as String?),
      );

  Map<String, dynamic> _toJson(AccountNode account) => {
        'account_name': account.title,
        'account_number': account.code,
        'parent_account': account.parentId,
        'is_group': account.level == AccountLevel.group ||
                account.level == AccountLevel.general
            ? 1
            : 0,
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
