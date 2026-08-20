import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/features/parties/data/repositories/server_first_party_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

void main() {
  const profile = PartyProfile(
    id: 'PARTY-1',
    company: 'دفتر',
    kind: PartyKind.individual,
    displayName: 'مشتری نمونه',
    roles: {PartyRole.customer},
    mobile: '09120000000',
  );

  test('شخص آنلاین روی سرور و سپس کش synced ذخیره می‌شود', () async {
    final local = FakeLocalRecordStore();
    final remote = _PartyRepository(profile);
    final repository = ServerFirstPartyRepository(remote, local: local);

    await repository.save(profile);

    expect(remote.saveCalls, 1);
    expect(local.records.values.single.status, LocalSyncStatus.synced);
  });

  test('شخص آفلاین pending می‌شود و در فهرست محلی باقی می‌ماند', () async {
    final local = FakeLocalRecordStore();
    final repository = ServerFirstPartyRepository(
      _PartyRepository(profile, error: _networkError),
      local: local,
    );

    final saved = await repository.save(profile);

    expect(saved.displayName, profile.displayName);
    expect(local.records.values.single.status, LocalSyncStatus.pendingSync);
    final values = await repository.list(company: 'دفتر');
    expect(values.single.displayName, profile.displayName);
    expect(values.single.mobile, profile.mobile);
  });

  test('کد آفلاین از ابتدای بازه گروه و سپس به‌ترتیب ساخته می‌شود', () async {
    final local = FakeLocalRecordStore();
    final repository = ServerFirstPartyRepository(
      _PartyRepository(profile, error: _networkError),
      local: local,
    );

    expect(await repository.previewNextCode('1000'), '1000');
    await expectLater(
      repository.createDetail(
        title: 'مشتری نمونه',
        type: 'Customer',
        detailGroup: '1000',
        profileId: 'PARTY-1',
      ),
      throwsA(_networkError),
    );
    expect(await repository.previewNextCode('1000'), '1001');
  });
}

const _networkError = ApiException(
  kind: ApiFailureKind.network,
  message: 'offline',
);

class _PartyRepository implements PartyRepository {
  _PartyRepository(this.profile, {this.error});
  final PartyProfile profile;
  final ApiException? error;
  int saveCalls = 0;
  void _check() {
    if (error != null) throw error!;
  }

  @override
  Future<PartyProfile> save(PartyProfile value,
      {PartyRole? primaryRole, Set<String> detailGroups = const {}}) async {
    saveCalls++;
    _check();
    return value;
  }

  @override
  Future<List<PartyProfile>> list(
      {String? company, PartyRole? role, String? search}) async {
    _check();
    return [profile];
  }

  @override
  Future<String> previewNextCode(String detailGroup) async {
    _check();
    return detailGroup;
  }

  @override
  Future<List<FloatingDetail>> listDetails(
      {String? detailGroup, String? search}) async {
    _check();
    return const [];
  }

  @override
  Future<void> disableParty(String id) async => _check();
  @override
  Future<FloatingDetail> createDetail(
      {required String title,
      required String type,
      required String detailGroup,
      required String profileId}) async {
    _check();
    throw StateError('unreachable');
  }

  @override
  Future<void> linkDetail(
          {required String detailId, required String profileId}) async =>
      _check();
}
