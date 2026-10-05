import 'package:asoud_erp/features/office_setup/data/demo/office_demo_data.dart';
import 'package:asoud_erp/features/parties/data/repositories/server_first_party_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

class _Remote extends Fake implements PartyRepository {
  @override
  Future<List<PartyProfile>> list(
          {String? company, PartyRole? role, String? search}) async =>
      const [];
  @override
  Future<PartyProfile> save(PartyProfile profile,
          {PartyRole? primaryRole,
          Set<String> detailGroups = const {}}) async =>
      profile;
  @override
  Future<String> previewNextCode(String detailGroup) async => '001';
  @override
  Future<List<FloatingDetail>> listDetails(
          {String? detailGroup, String? search}) async =>
      const [];
  @override
  Future<void> disableParty(String id) async {}
  @override
  Future<FloatingDetail> createDetail(
          {required String title,
          required String type,
          required String detailGroup,
          required String profileId}) async =>
      throw UnimplementedError();
  @override
  Future<void> linkDetail(
      {required String detailId, required String profileId}) async {}
}

void main() {
  test('preview offers demo customers and suppliers', () async {
    final repository = ServerFirstPartyRepository(_Remote(),
        local: FakeLocalRecordStore(), localPreview: () => true);
    final rows = await repository.list(company: demoCompanyName);
    expect(rows.map((row) => row.displayName),
        containsAll(['فروشگاه نمونه تهران', 'شرکت پخش نمونه']));
    expect(
        rows.where((row) => row.roles.contains(PartyRole.customer)).length, 2);
    expect(
        rows.where((row) => row.roles.contains(PartyRole.supplier)).length, 2);
    expect(
        await repository.list(
            company: demoCompanyName, role: PartyRole.customer),
        hasLength(2));
  });

  test('a saved party replaces the demos in preview', () async {
    final repository = ServerFirstPartyRepository(_Remote(),
        local: FakeLocalRecordStore(), localPreview: () => true);
    await repository.save(const PartyProfile(
      company: demoCompanyName,
      kind: PartyKind.organization,
      displayName: 'مشتری واقعی من',
      roles: {PartyRole.customer},
    ));
    final rows = await repository.list(company: demoCompanyName);
    expect(rows.map((row) => row.displayName), ['مشتری واقعی من']);
  });

  test('an authenticated session never sees the demo parties', () async {
    final repository =
        ServerFirstPartyRepository(_Remote(), local: FakeLocalRecordStore());
    expect(await repository.list(company: demoCompanyName), isEmpty);
  });
}
