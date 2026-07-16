import 'dart:convert';

import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/detail_group.dart';
import '../../domain/entities/account_detail_mapping.dart';
import '../../domain/entities/floating_detail.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/parties_repository.dart';

class FrappePartiesRepository implements PartiesRepository {
  const FrappePartiesRepository(this._client);
  final FrappeClient _client;

  @override
  Future<List<DetailGroup>> getDetailGroups() async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.detail_group.list_detail_groups',
      _decodeList,
    );
    return response.data
        .map((row) => DetailGroup(code: row['group_code'].toString(), title: row['group_name'].toString()))
        .toList();
  }

  @override
  Future<List<FloatingDetail>> getFloatingDetails({String? search}) async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.floating_detail.list_floating_details',
      _decodeList,
      data: {if (search?.isNotEmpty ?? false) 'search': search},
    );
    return response.data.map(_detailFromJson).toList();
  }

  @override
  Future<FloatingDetail> createFloatingDetail(FloatingDetail detail) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.floating_detail.create_floating_detail',
      _decodeMap,
      data: {
        'title': detail.title,
        'detail_type': detail.type,
        'detail_group': detail.groupCode,
        if (detail.code.isNotEmpty) 'detail_code': detail.code,
      },
    );
    return _detailFromJson(response.data);
  }

  @override
  Future<List<PartyProfile>> getParties({String? search}) async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.party.list_parties',
      _decodeList,
      data: {if (search?.isNotEmpty ?? false) 'search': search},
    );
    return response.data.map(_partyFromJson).toList();
  }

  @override
  Future<PartyProfile> saveParty(PartyProfile party) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.party.save_party',
      _decodeMap,
      data: {
        if (party.id.isNotEmpty) 'name': party.id,
        'party_type': party.type == PartyType.individual ? 'Individual' : 'Organization',
        'display_name': party.displayName,
        'national_id': party.nationalId,
        'mobile': party.mobile,
        'email': party.email,
        'roles': jsonEncode(party.roles.map(_roleToApi).toList()),
      },
    );
    return _partyFromJson(response.data);
  }

  @override
  Future<List<AccountDetailMapping>> getAccountMappings(String company) async {
    final response = await _client.callAsoudMethod<List<Map<String, dynamic>>>(
      'asoud_erp.api.v1.detail_group.list_account_mappings',
      _decodeList,
      data: {'company': company},
    );
    return response.data
        .map((row) => AccountDetailMapping(accountId: row['account'].toString(), groupCode: row['detail_group'].toString()))
        .toList();
  }

  @override
  Future<AccountDetailMapping> saveAccountMapping(String company, AccountDetailMapping mapping) async {
    final response = await _client.callAsoudMethod<Map<String, dynamic>>(
      'asoud_erp.api.v1.detail_group.save_account_mapping',
      _decodeMap,
      data: {'company': company, 'account': mapping.accountId, 'detail_group': mapping.groupCode},
    );
    return AccountDetailMapping(
      accountId: response.data['account'].toString(),
      groupCode: response.data['detail_group'].toString(),
    );
  }

  static List<Map<String, dynamic>> _decodeList(Object? value) => (value as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  static Map<String, dynamic> _decodeMap(Object? value) => Map<String, dynamic>.from(value! as Map);

  FloatingDetail _detailFromJson(Map<String, dynamic> row) => FloatingDetail(
        id: row['name']?.toString() ?? '',
        code: row['detail_code']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        type: row['detail_type']?.toString() ?? 'Other',
        groupCode: row['detail_group']?.toString() ?? '',
      );

  PartyProfile _partyFromJson(Map<String, dynamic> row) => PartyProfile(
        id: row['name']?.toString() ?? '',
        type: row['party_type'] == 'Organization' ? PartyType.organization : PartyType.individual,
        displayName: row['display_name']?.toString() ?? '',
        nationalId: row['national_id']?.toString() ?? '',
        mobile: row['mobile']?.toString() ?? '',
        email: row['email']?.toString() ?? '',
        roles: ((row['roles'] as List?) ?? const [])
            .map((value) => _roleFromApi(value.toString()))
            .toSet(),
      );

  String _roleToApi(PartyRole role) => switch (role) {
        PartyRole.customer => 'Customer',
        PartyRole.supplier => 'Supplier',
        PartyRole.employee => 'Employee',
        PartyRole.shareholder => 'Shareholder',
        PartyRole.other => 'Other',
      };

  PartyRole _roleFromApi(String value) => switch (value) {
        'Customer' => PartyRole.customer,
        'Supplier' => PartyRole.supplier,
        'Employee' => PartyRole.employee,
        'Shareholder' => PartyRole.shareholder,
        _ => PartyRole.other,
      };
}
