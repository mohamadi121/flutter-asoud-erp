import '../entities/account_node.dart';

abstract interface class ChartOfAccountsRepository {
  Future<List<AccountNode>> getAccounts(String company);
  Future<AccountNode> createAccount(String company, AccountNode account,
      {required bool autoCode});
  Future<AccountNode> updateAccount(String company, AccountNode account);
}
