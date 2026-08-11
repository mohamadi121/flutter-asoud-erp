import '../../../../core/offline/local_database_store.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/account_node.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class ServerFirstChartOfAccountsRepository
    implements ChartOfAccountsRepository {
  ServerFirstChartOfAccountsRepository(this._remote, {LocalRecordStore? local})
      : _local = local ?? LocalDatabaseStore.instance;

  final ChartOfAccountsRepository _remote;
  final LocalRecordStore _local;

  @override
  Future<List<AccountNode>> getAccounts(String company) async {
    try {
      final remote = await _remote.getAccounts(company);
      for (final account in remote) {
        await _cacheRemote(company, account);
      }
      return _merge(remote, await _localAccounts(company));
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _localAccounts(company);
    }
  }

  @override
  Future<AccountNode> createAccount(
    String company,
    AccountNode account, {
    required bool autoCode,
  }) =>
      _write(company, account,
          () => _remote.createAccount(company, account, autoCode: autoCode));

  @override
  Future<AccountNode> updateAccount(String company, AccountNode account) =>
      _write(company, account, () => _remote.updateAccount(company, account));

  Future<AccountNode> _write(
    String company,
    AccountNode draft,
    Future<AccountNode> Function() remote,
  ) async {
    try {
      final saved = await remote();
      await _save(company, saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _save(company, draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<List<AccountNode>> importAccounts(
    String company,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final saved = await _remote.importAccounts(company, rows);
      for (final account in saved) {
        await _save(company, account, LocalSyncStatus.synced);
      }
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _local.save(
        id: 'account-import:${Uri.encodeComponent(company)}',
        entityType: 'account_import:$company',
        payload: {'rows': rows},
        status: LocalSyncStatus.pendingSync,
      );
      rethrow;
    }
  }

  @override
  Future<List<AccountNode>> applyTemplate(
      String company, String template) async {
    try {
      final saved = await _remote.applyTemplate(company, template);
      for (final account in saved) {
        await _save(company, account, LocalSyncStatus.synced);
      }
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _local.save(
        id: 'account-template:${Uri.encodeComponent(company)}',
        entityType: 'account_template:$company',
        payload: {'template': template},
        status: LocalSyncStatus.pendingSync,
      );
      rethrow;
    }
  }

  @override
  Future<List<ChartTemplateRow>> previewTemplate(
    String company,
    String template,
  ) =>
      _remote.previewTemplate(company, template);

  Future<void> _cacheRemote(String company, AccountNode account) async {
    final existing = await _local.get(_id(company, account));
    if (existing != null &&
        const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
            .contains(existing.status)) {
      return;
    }
    await _save(company, account, LocalSyncStatus.synced);
  }

  Future<void> _save(
    String company,
    AccountNode account,
    LocalSyncStatus status,
  ) =>
      _local.save(
        id: _id(company, account),
        entityType: 'account:$company',
        payload: _encode(account),
        status: status,
      );

  Future<List<AccountNode>> _localAccounts(String company) async =>
      (await _local.list(entityType: 'account:$company'))
          .map((record) => _decode(record.payload))
          .toList(growable: false);

  List<AccountNode> _merge(List<AccountNode> remote, List<AccountNode> local) {
    final values = <String, AccountNode>{
      for (final item in remote) _key(item): item
    };
    for (final item in local) {
      values[_key(item)] = item;
    }
    return values.values.toList(growable: false);
  }

  String _id(String company, AccountNode value) =>
      'account:${Uri.encodeComponent(company)}:${Uri.encodeComponent(_key(value))}';
  String _key(AccountNode value) => value.id.isNotEmpty
      ? value.id
      : '${value.level.name}:${value.code}:${value.title}';

  Map<String, dynamic> _encode(AccountNode value) => {
        'id': value.id,
        'code': value.code,
        'title': value.title,
        'level': value.level.name,
        'parent_id': value.parentId,
        'is_active': value.isActive,
        'nature': value.nature.name,
        'account_type': value.accountType,
      };

  AccountNode _decode(Map<String, dynamic> value) => AccountNode(
        id: value['id']?.toString() ?? '',
        code: value['code']?.toString() ?? '',
        title: value['title']?.toString() ?? '',
        level: AccountLevel.values.byName(value['level'] as String),
        parentId: value['parent_id']?.toString(),
        isActive: value['is_active'] != false,
        nature: AccountNature.values.byName(value['nature'] as String),
        accountType: value['account_type']?.toString() ?? '',
      );
}
