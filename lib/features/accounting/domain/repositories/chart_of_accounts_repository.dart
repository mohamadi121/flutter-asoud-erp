import '../entities/account_node.dart';

abstract interface class ChartOfAccountsRepository {
  Future<List<AccountNode>> getAccounts(String company);
  Future<AccountNode> createAccount(String company, AccountNode account,
      {required bool autoCode});
  Future<AccountNode> updateAccount(String company, AccountNode account);
  Future<void> deleteAccount(String company, AccountNode account);
  Future<List<AccountNode>> importAccounts(
      String company, List<Map<String, dynamic>> rows);
  Future<List<ChartTemplateRow>> previewTemplate(
      String company, String template);
  Future<List<AccountNode>> applyTemplate(String company, String template);
}

class ChartTemplateRow {
  const ChartTemplateRow({
    required this.key,
    required this.level,
    required this.title,
    this.parentKey,
  });
  final String key, level, title;
  final String? parentKey;
}
