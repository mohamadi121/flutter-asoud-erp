import '../entities/account_detail_mapping.dart';
import '../entities/detail_group.dart';
import '../entities/floating_detail.dart';
import '../entities/party_profile.dart';

abstract interface class PartiesRepository {
  Future<List<DetailGroup>> getDetailGroups();
  Future<List<FloatingDetail>> getFloatingDetails({String? search});
  Future<FloatingDetail> createFloatingDetail(FloatingDetail detail);
  Future<List<PartyProfile>> getParties({String? search});
  Future<PartyProfile> saveParty(PartyProfile party);
  Future<List<AccountDetailMapping>> getAccountMappings(String company);
  Future<AccountDetailMapping> saveAccountMapping(String company, AccountDetailMapping mapping);
}
