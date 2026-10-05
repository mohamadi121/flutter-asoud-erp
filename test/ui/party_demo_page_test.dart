import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/data/demo/office_demo_data.dart';
import 'package:asoud_erp/features/parties/data/repositories/server_first_party_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_local_record_store.dart';

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
  testWidgets('preview parties page renders demo customers at 390',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = ServerFirstPartyRepository(_Remote(),
        local: FakeLocalRecordStore(), localPreview: () => true);
    await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: RepositoryProvider<PartyRepository>.value(
        value: repository,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: PartyManagementPage(company: demoCompanyName),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('فروشگاه نمونه تهران'), findsOneWidget);
    expect(find.text('شرکت پخش نمونه'), findsOneWidget);
    expect(find.text('هنوز شخصی در این بخش ثبت نشده است.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
