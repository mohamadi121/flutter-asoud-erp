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
      {PartyRole? primaryRole, Set<String> detailGroups = const {}}) async {
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
        'detail_groups': jsonEncode(detailGroups.toList()),
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
        'employee_gender': value.employeeGender,
        'date_of_joining': value.dateOfJoining,
        'father_name': value.fatherName,
        'birth_certificate_number': value.birthCertificateNumber,
        'birth_certificate_issue_place': value.birthCertificateIssuePlace,
        'employment_type': value.employmentType,
        'job_title': value.jobTitle,
        'department': value.department,
        'description': value.description,
        'alias_name': value.aliasName,
        'manager_name': value.managerName,
        'registration_number': value.registrationNumber,
        'economic_code': value.economicCode,
        'founding_date': value.foundingDate,
        'secondary_phone': value.secondaryPhone,
        'credit_limit': value.creditLimit,
        'opening_balance': value.openingBalance,
        'balance_type': value.balanceType,
        'card_number': value.cardNumber,
        'account_holder': value.accountHolder,
        'region': value.region,
        'neighborhood': value.neighborhood,
        'plaque': value.plaque,
        'unit': value.unit,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'employee_roles': jsonEncode(value.employeeRoles.toList()),
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
        groupTitle: item['group_title']?.toString(),
        linkedDocument: item['linked_document']?.toString(),
      );
    }).toList(growable: false);
  }

  PartyProfile _profile(Map raw) {
    final item = Map<String, dynamic>.from(raw);
    final roles = (item['roles'] as List? ?? const [])
        .map((value) => _parseRole(value.toString()))
        .whereType<PartyRole>()
        .toSet();
    final details = (item['floating_details'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
      final detail = Map<String, dynamic>.from(raw);
      return FloatingDetail(
        id: detail['name']?.toString() ?? '',
        code: detail['detail_code']?.toString() ?? '',
        title: item['display_name']?.toString() ?? '',
        type: detail['detail_type']?.toString() ?? '',
        groupId: detail['detail_group']?.toString() ?? '',
        groupTitle: detail['group_title']?.toString(),
        linkedDocument: detail['linked_document']?.toString(),
      );
    }).toList(growable: false);
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
      employeeGender: item['employee_gender']?.toString(),
      dateOfJoining: item['date_of_joining']?.toString(),
      fatherName: item['father_name']?.toString(),
      birthCertificateNumber: item['birth_certificate_number']?.toString(),
      birthCertificateIssuePlace:
          item['birth_certificate_issue_place']?.toString(),
      employmentType: item['employment_type']?.toString(),
      jobTitle: item['job_title']?.toString(),
      department: item['department']?.toString(),
      description: item['description']?.toString(),
      aliasName: item['alias_name']?.toString(),
      managerName: item['manager_name']?.toString(),
      registrationNumber: item['registration_number']?.toString(),
      economicCode: item['economic_code']?.toString(),
      foundingDate: item['founding_date']?.toString(),
      secondaryPhone: item['secondary_phone']?.toString(),
      creditLimit: _double(item['credit_limit']),
      openingBalance: _double(item['opening_balance']),
      balanceType: item['balance_type']?.toString(),
      cardNumber: item['card_number']?.toString(),
      accountHolder: item['account_holder']?.toString(),
      region: item['region']?.toString(),
      neighborhood: item['neighborhood']?.toString(),
      plaque: item['plaque']?.toString(),
      unit: item['unit']?.toString(),
      latitude: _double(item['latitude']),
      longitude: _double(item['longitude']),
      employeeRoles: _strings(item['employee_roles']),
      detailGroups: details.map((value) => value.groupId).toSet(),
      floatingDetails: details,
      disabled: item['disabled'] == 1 || item['disabled'] == true,
    );
  }

  @override
  Future<void> disableParty(String id) async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.party.disable_party',
      data: {'name': id},
    );
  }

  @override
  Future<FloatingDetail> createDetail({
    required String title,
    required String type,
    required String detailGroup,
    required String profileId,
  }) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.floating_detail.create_floating_detail',
      data: {
        'title': title,
        'detail_type': type,
        'detail_group': detailGroup,
        'linked_doctype': 'ASOUD Party Profile',
        'linked_document': profileId,
      },
    );
    if (data is! Map) throw StateError('Invalid floating detail response');
    final item = Map<String, dynamic>.from(data);
    return FloatingDetail(
      id: item['name']?.toString() ?? '',
      code: item['detail_code']?.toString() ?? '',
      title: item['title']?.toString() ?? title,
      type: item['detail_type']?.toString() ?? type,
      groupId: item['detail_group']?.toString() ?? detailGroup,
      groupTitle: item['group_title']?.toString(),
    );
  }

  @override
  Future<void> linkDetail(
      {required String detailId, required String profileId}) async {
    await _client.callAsoudMethod(
      'asoud_erp.api.v1.floating_detail.link_floating_detail',
      data: {'name': detailId, 'party_profile': profileId},
    );
  }

  static double? _double(dynamic value) => value == null
      ? null
      : value is num
          ? value.toDouble()
          : double.tryParse(value.toString());

  static Set<String> _strings(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toSet();
    if (value is String && value.isNotEmpty) {
      final parsed = jsonDecode(value);
      if (parsed is List) return parsed.map((item) => item.toString()).toSet();
    }
    return const {};
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
