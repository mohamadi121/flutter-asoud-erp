import 'dart:convert';

import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

class FrappePartyRepository implements PartyRepository {
  const FrappePartyRepository(this._client);
  final FrappeApiClient _client;

  @override
  Future<List<PartyProfile>> list(
      {String? company, PartyRole? role, String? search}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.party.list_parties',
      data: {
        if (company != null) 'company': company,
        if (role != null) 'role': _role(role),
        if (search?.isNotEmpty == true) 'search': search,
      },
    );
    if (data is! List) return const [];
    return data.whereType<Map>().map(_profile).toList(growable: false);
  }

  @override
  Future<PartyProfile> save(PartyProfile value,
      {PartyRole? primaryRole, String? detailGroup}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.party.save_party',
      data: {
        'name': value.id,
        'company': value.company,
        'party_type':
            value.kind == PartyKind.individual ? 'Individual' : 'Organization',
        'display_name': value.displayName,
        'roles': jsonEncode(value.roles.map(_role).toList()),
        'primary_role': primaryRole == null ? null : _role(primaryRole),
        'detail_group': detailGroup,
        'national_id': value.nationalId,
        'mobile': value.mobile,
        'phone': value.phone,
        'email': value.email,
        'website': value.website,
        'province': value.province,
        'city': value.city,
        'address_line': value.address,
        'postal_code': value.postalCode,
        'bank_name': value.bankName,
        'iban': value.iban,
        'account_number': value.accountNumber,
        'birth_date': value.birthDate,
        'employment_type': value.employmentType,
        'job_title': value.jobTitle,
        'department': value.department,
        'description': value.description,
      },
    );
    if (data is! Map) throw StateError('Invalid party response');
    return _profile(data);
  }

  @override
  Future<String> previewNextCode(String detailGroup) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.floating_detail.preview_next_detail_code',
      data: {'detail_group': detailGroup},
    );
    if (data is! Map || data['detail_code'] == null) {
      throw StateError('Invalid detail-code response');
    }
    return data['detail_code'].toString();
  }

  @override
  Future<List<FloatingDetail>> listDetails(
      {String? detailGroup, String? search}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.floating_detail.list_floating_details',
      data: {
        if (detailGroup != null) 'detail_group': detailGroup,
        if (search?.isNotEmpty == true) 'search': search,
      },
    );
    if (data is! List) return const [];
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return FloatingDetail(
        id: item['name']?.toString() ?? '',
        code: item['detail_code']?.toString() ?? '',
        title: item['title']?.toString() ?? '',
        type: item['detail_type']?.toString() ?? '',
        groupId: item['detail_group']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  PartyProfile _profile(Map raw) {
    final item = Map<String, dynamic>.from(raw);
    final roles = (item['roles'] as List? ?? const [])
        .map((value) => _parseRole(value.toString()))
        .whereType<PartyRole>()
        .toSet();
    return PartyProfile(
      id: item['name']?.toString(),
      company: item['company']?.toString(),
      kind: item['party_type'] == 'Organization'
          ? PartyKind.organization
          : PartyKind.individual,
      displayName: item['display_name']?.toString() ?? '',
      roles: roles,
      nationalId: item['national_id']?.toString(),
      mobile: item['mobile']?.toString(),
      phone: item['phone']?.toString(),
      email: item['email']?.toString(),
      website: item['website']?.toString(),
      province: item['province']?.toString(),
      city: item['city']?.toString(),
      address: item['address_line']?.toString(),
      postalCode: item['postal_code']?.toString(),
      bankName: item['bank_name']?.toString(),
      iban: item['iban']?.toString(),
      accountNumber: item['account_number']?.toString(),
      birthDate: item['birth_date']?.toString(),
      employmentType: item['employment_type']?.toString(),
      jobTitle: item['job_title']?.toString(),
      department: item['department']?.toString(),
      description: item['description']?.toString(),
    );
  }

  static String _role(PartyRole role) => switch (role) {
        PartyRole.customer => 'Customer',
        PartyRole.supplier => 'Supplier',
        PartyRole.employee => 'Employee',
        PartyRole.shareholder => 'Shareholder',
        PartyRole.other => 'Other',
      };

  static PartyRole? _parseRole(String role) => switch (role) {
        'Customer' => PartyRole.customer,
        'Supplier' => PartyRole.supplier,
        'Employee' => PartyRole.employee,
        'Shareholder' => PartyRole.shareholder,
        'Other' => PartyRole.other,
        _ => null,
      };
}
