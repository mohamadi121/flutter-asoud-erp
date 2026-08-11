import '../entities/party_profile.dart';

abstract interface class PartyRepository {
  Future<List<PartyProfile>> list(
      {String? company, PartyRole? role, String? search});
  Future<PartyProfile> save(PartyProfile profile,
      {PartyRole? primaryRole, Set<String> detailGroups = const {}});
  Future<String> previewNextCode(String detailGroup);
  Future<List<FloatingDetail>> listDetails(
      {String? detailGroup, String? search});
  Future<void> disableParty(String id);
  Future<FloatingDetail> createDetail({
    required String title,
    required String type,
    required String detailGroup,
    required String profileId,
  });
  Future<void> linkDetail(
      {required String detailId, required String profileId});
}
