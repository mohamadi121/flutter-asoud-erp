import '../entities/account_node.dart';

abstract interface class ChartOfAccountsRepository {
  Future<List<AccountNode>> getAccounts();
  Future<AccountNode> createAccount(AccountNode account);
  Future<AccountNode> updateAccount(AccountNode account);
}

