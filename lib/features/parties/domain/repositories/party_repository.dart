import '../entities/party_profile.dart';

abstract interface class PartyRepository {
  Future<List<PartyProfile>> list(
      {String? company, PartyRole? role, String? search});
  Future<PartyProfile> save(PartyProfile profile,
      {PartyRole? primaryRole, String? detailGroup});
  Future<String> previewNextCode(String detailGroup);
  Future<List<FloatingDetail>> listDetails(
      {String? detailGroup, String? search});
}
