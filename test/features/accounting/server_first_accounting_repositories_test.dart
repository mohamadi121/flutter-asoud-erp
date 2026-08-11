import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/accounting/data/repositories/server_first_chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/data/repositories/server_first_detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  const account = AccountNode(
    id: 'ACC-1',
    code: '101',
    title: 'موجودی نقد',
    level: AccountLevel.general,
  );
  const group = DetailGroup(id: 'DG-1', code: '1000', title: 'مشتریان');

  test('سرفصل در حالت آنلاین ابتدا سرور و سپس کش synced می‌شود', () async {
    final local = FakeLocalRecordStore();
    final remote = _ChartRepository(account);
    final repository =
        ServerFirstChartOfAccountsRepository(remote, local: local);

    await repository.createAccount('دفتر', account, autoCode: true);

    expect(remote.createCalls, 1);
    expect(local.records.values.single.status, LocalSyncStatus.synced);
  });

  test('سرفصل در قطع اتصال pending ذخیره و از فهرست محلی خوانده می‌شود',
      () async {
    final local = FakeLocalRecordStore();
    final repository = ServerFirstChartOfAccountsRepository(
      _ChartRepository(account, error: _networkError),
      local: local,
    );

    await expectLater(
      repository.createAccount('دفتر', account, autoCode: true),
      throwsA(_networkError),
    );

    expect(local.records.values.single.status, LocalSyncStatus.pendingSync);
    expect((await repository.getAccounts('دفتر')).single, account);
  });

  test('گروه تفصیلی در قطع اتصال pending ذخیره می‌شود', () async {
    final local = FakeLocalRecordStore();
    final repository = ServerFirstDetailGroupRepository(
      _DetailGroupRepository(group, error: _networkError),
      local: local,
    );

    await expectLater(
      repository.saveGroup(code: group.code, title: group.title, id: group.id),
      throwsA(_networkError),
    );

    expect(local.records.values.single.status, LocalSyncStatus.pendingSync);
    expect((await repository.getGroups()).single.title, group.title);
  });
}

const _networkError = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

class _ChartRepository implements ChartOfAccountsRepository {
  _ChartRepository(this.account, {this.error});
  final AccountNode account;
  final ApiException? error;
  int createCalls = 0;
  void _check() {
    if (error != null) throw error!;
  }

  @override
  Future<AccountNode> createAccount(String company, AccountNode value,
      {required bool autoCode}) async {
    createCalls++;
    _check();
    return value;
  }

  @override
  Future<List<AccountNode>> getAccounts(String company) async {
    _check();
    return [account];
  }

  @override
  Future<AccountNode> updateAccount(String company, AccountNode value) async {
    _check();
    return value;
  }

  @override
  Future<List<AccountNode>> importAccounts(
      String company, List<Map<String, dynamic>> rows) async {
    _check();
    return [account];
  }

  @override
  Future<List<AccountNode>> applyTemplate(
      String company, String template) async {
    _check();
    return [account];
  }

  @override
  Future<List<ChartTemplateRow>> previewTemplate(
      String company, String template) async {
    _check();
    return const [];
  }
}

class _DetailGroupRepository implements DetailGroupRepository {
  _DetailGroupRepository(this.group, {this.error});
  final DetailGroup group;
  final ApiException? error;
  void _check() {
    if (error != null) throw error!;
  }

  @override
  Future<void> disableGroup(String id) async => _check();
  @override
  Future<List<DetailGroup>> getGroups() async {
    _check();
    return [group];
  }

  @override
  Future<DetailGroup> saveGroup(
      {required String code, required String title, String? id}) async {
    _check();
    return group;
  }

  @override
  Future<List<DetailGroup>> seedDefaults() async {
    _check();
    return [group];
  }
}
