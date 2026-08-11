import '../../../../core/offline/local_database_store.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

class ServerFirstPartyRepository implements PartyRepository {
  ServerFirstPartyRepository(this._remote, {LocalRecordStore? local})
      : _local = local ?? LocalDatabaseStore.instance;

  final PartyRepository _remote;
  final LocalRecordStore _local;

  @override
  Future<List<PartyProfile>> list({
    String? company,
    PartyRole? role,
    String? search,
  }) async {
    try {
      final remote =
          await _remote.list(company: company, role: role, search: search);
      for (final profile in remote) {
        await _cacheProfile(profile);
      }
      return _filter(
          _merge(remote, await _localProfiles()), company, role, search);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _filter(await _localProfiles(), company, role, search);
    }
  }

  @override
  Future<PartyProfile> save(
    PartyProfile profile, {
    PartyRole? primaryRole,
    Set<String> detailGroups = const {},
  }) async {
    final draft = _copyProfile(profile, detailGroups: detailGroups);
    try {
      final saved = await _remote.save(
        profile,
        primaryRole: primaryRole,
        detailGroups: detailGroups,
      );
      await _saveProfile(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _saveProfile(draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<String> previewNextCode(String detailGroup) async {
    try {
      return await _remote.previewNextCode(detailGroup);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final details = await _localDetails(detailGroup: detailGroup);
      final codes =
          details.map((item) => int.tryParse(item.code)).whereType<int>();
      return (codes.isEmpty
              ? int.tryParse(detailGroup) ?? 1
              : codes.reduce((a, b) => a > b ? a : b) + 1)
          .toString();
    }
  }

  @override
  Future<List<FloatingDetail>> listDetails({
    String? detailGroup,
    String? search,
  }) async {
    try {
      final remote = await _remote.listDetails(
        detailGroup: detailGroup,
        search: search,
      );
      for (final detail in remote) {
        await _cacheDetail(detail);
      }
      return _filterDetails(
        _mergeDetails(remote, await _localDetails()),
        detailGroup,
        search,
      );
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      return _filterDetails(await _localDetails(), detailGroup, search);
    }
  }

  @override
  Future<FloatingDetail> createDetail({
    required String title,
    required String type,
    required String detailGroup,
    required String profileId,
  }) async {
    try {
      final saved = await _remote.createDetail(
        title: title,
        type: type,
        detailGroup: detailGroup,
        profileId: profileId,
      );
      await _saveDetail(saved, LocalSyncStatus.synced);
      return saved;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final code = await previewNextCode(detailGroup);
      final draft = FloatingDetail(
        id: 'LOCAL-$detailGroup-$code',
        code: code,
        title: title,
        type: type,
        groupId: detailGroup,
        linkedDocument: profileId,
      );
      await _saveDetail(draft, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<void> disableParty(String id) async {
    try {
      await _remote.disableParty(id);
      await _setPartyDisabled(id, LocalSyncStatus.synced);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _setPartyDisabled(id, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  @override
  Future<void> linkDetail(
      {required String detailId, required String profileId}) async {
    try {
      await _remote.linkDetail(detailId: detailId, profileId: profileId);
      await _setDetailLink(detailId, profileId, LocalSyncStatus.synced);
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      await _setDetailLink(detailId, profileId, LocalSyncStatus.pendingSync);
      rethrow;
    }
  }

  Future<void> _cacheProfile(PartyProfile value) async {
    final existing = await _local.get(_profileId(value));
    if (_isPending(existing)) return;
    await _saveProfile(value, LocalSyncStatus.synced);
  }

  Future<void> _cacheDetail(FloatingDetail value) async {
    final existing = await _local.get(_detailId(value));
    if (_isPending(existing)) return;
    await _saveDetail(value, LocalSyncStatus.synced);
  }

  bool _isPending(LocalRecord? record) =>
      record != null &&
      const {LocalSyncStatus.localOnly, LocalSyncStatus.pendingSync}
          .contains(record.status);

  Future<void> _saveProfile(PartyProfile value, LocalSyncStatus status) =>
      _local.save(
        id: _profileId(value),
        entityType: 'party_profile',
        payload: _profileToMap(value),
        status: status,
      );

  Future<void> _saveDetail(FloatingDetail value, LocalSyncStatus status) =>
      _local.save(
        id: _detailId(value),
        entityType: 'floating_detail',
        payload: _detailToMap(value),
        status: status,
      );

  Future<List<PartyProfile>> _localProfiles() async =>
      (await _local.list(entityType: 'party_profile'))
          .map((record) => _profileFromMap(record.payload))
          .toList(growable: false);

  Future<List<FloatingDetail>> _localDetails({String? detailGroup}) async =>
      (await _local.list(entityType: 'floating_detail'))
          .map((record) => _detailFromMap(record.payload))
          .where((item) => detailGroup == null || item.groupId == detailGroup)
          .toList(growable: false);

  Future<void> _setPartyDisabled(String id, LocalSyncStatus status) async {
    final profile =
        (await _localProfiles()).where((item) => item.id == id).firstOrNull;
    if (profile != null) {
      await _saveProfile(_copyProfile(profile, disabled: true), status);
    }
  }

  Future<void> _setDetailLink(
    String id,
    String profileId,
    LocalSyncStatus status,
  ) async {
    final detail =
        (await _localDetails()).where((item) => item.id == id).firstOrNull;
    if (detail == null) return;
    await _saveDetail(
      FloatingDetail(
        id: detail.id,
        code: detail.code,
        title: detail.title,
        type: detail.type,
        groupId: detail.groupId,
        groupTitle: detail.groupTitle,
        linkedDocument: profileId,
      ),
      status,
    );
  }

  List<PartyProfile> _merge(
      List<PartyProfile> remote, List<PartyProfile> local) {
    final result = <String, PartyProfile>{
      for (final item in remote) _profileKey(item): item
    };
    for (final item in local) {
      result[_profileKey(item)] = item;
    }
    return result.values.toList(growable: false);
  }

  List<FloatingDetail> _mergeDetails(
      List<FloatingDetail> remote, List<FloatingDetail> local) {
    final result = <String, FloatingDetail>{
      for (final item in remote) _detailKey(item): item
    };
    for (final item in local) {
      result[_detailKey(item)] = item;
    }
    return result.values.toList(growable: false);
  }

  List<PartyProfile> _filter(List<PartyProfile> values, String? company,
          PartyRole? role, String? search) =>
      values.where((item) {
        final query = search?.trim().toLowerCase();
        return (company == null || item.company == company) &&
            (role == null || item.roles.contains(role)) &&
            (query == null ||
                query.isEmpty ||
                item.displayName.toLowerCase().contains(query));
      }).toList(growable: false);

  List<FloatingDetail> _filterDetails(
          List<FloatingDetail> values, String? group, String? search) =>
      values.where((item) {
        final query = search?.trim().toLowerCase();
        return (group == null || item.groupId == group) &&
            (query == null ||
                query.isEmpty ||
                item.title.toLowerCase().contains(query) ||
                item.code.contains(query));
      }).toList(growable: false);

  String _profileId(PartyProfile value) =>
      'party:${Uri.encodeComponent(_profileKey(value))}';
  String _profileKey(PartyProfile value) => value.id?.isNotEmpty == true
      ? value.id!
      : '${value.company}:${value.kind.name}:${value.displayName}';
  String _detailId(FloatingDetail value) =>
      'detail:${Uri.encodeComponent(_detailKey(value))}';
  String _detailKey(FloatingDetail value) =>
      value.id.isNotEmpty ? value.id : '${value.groupId}:${value.code}';

  Map<String, dynamic> _detailToMap(FloatingDetail value) => {
        'id': value.id,
        'code': value.code,
        'title': value.title,
        'type': value.type,
        'group_id': value.groupId,
        'group_title': value.groupTitle,
        'linked_document': value.linkedDocument,
      };
  FloatingDetail _detailFromMap(Map<String, dynamic> value) => FloatingDetail(
        id: value['id']?.toString() ?? '',
        code: value['code']?.toString() ?? '',
        title: value['title']?.toString() ?? '',
        type: value['type']?.toString() ?? '',
        groupId: value['group_id']?.toString() ?? '',
        groupTitle: value['group_title']?.toString(),
        linkedDocument: value['linked_document']?.toString(),
      );

  Map<String, dynamic> _profileToMap(PartyProfile value) => {
        'id': value.id,
        'company': value.company,
        'kind': value.kind.name,
        'display_name': value.displayName,
        'roles': value.roles.map((e) => e.name).toList(),
        'national_id': value.nationalId,
        'mobile': value.mobile,
        'phone': value.phone,
        'email': value.email,
        'website': value.website,
        'province': value.province,
        'city': value.city,
        'address': value.address,
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
        'alias_name': value.aliasName,
        'manager_name': value.managerName,
        'registration_number': value.registrationNumber,
        'economic_code': value.economicCode,
        'founding_date': value.foundingDate,
        'secondary_phone': value.secondaryPhone,
        'credit_limit': value.creditLimit,
        'card_number': value.cardNumber,
        'account_holder': value.accountHolder,
        'region': value.region,
        'neighborhood': value.neighborhood,
        'plaque': value.plaque,
        'unit': value.unit,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'description': value.description,
        'opening_balance': value.openingBalance,
        'balance_type': value.balanceType,
        'detail_groups': value.detailGroups.toList(),
        'employee_roles': value.employeeRoles.toList(),
        'disabled': value.disabled,
      };

  PartyProfile _profileFromMap(Map<String, dynamic> value) => PartyProfile(
        id: value['id']?.toString(),
        company: value['company']?.toString(),
        kind: PartyKind.values.byName(value['kind'] as String),
        displayName: value['display_name']?.toString() ?? '',
        roles: (value['roles'] as List? ?? const [])
            .map((e) => PartyRole.values.byName(e.toString()))
            .toSet(),
        nationalId: value['national_id']?.toString(),
        mobile: value['mobile']?.toString(),
        phone: value['phone']?.toString(),
        email: value['email']?.toString(),
        website: value['website']?.toString(),
        province: value['province']?.toString(),
        city: value['city']?.toString(),
        address: value['address']?.toString(),
        postalCode: value['postal_code']?.toString(),
        bankName: value['bank_name']?.toString(),
        iban: value['iban']?.toString(),
        accountNumber: value['account_number']?.toString(),
        birthDate: value['birth_date']?.toString(),
        employeeGender: value['employee_gender']?.toString(),
        dateOfJoining: value['date_of_joining']?.toString(),
        fatherName: value['father_name']?.toString(),
        birthCertificateNumber: value['birth_certificate_number']?.toString(),
        birthCertificateIssuePlace:
            value['birth_certificate_issue_place']?.toString(),
        employmentType: value['employment_type']?.toString(),
        jobTitle: value['job_title']?.toString(),
        department: value['department']?.toString(),
        aliasName: value['alias_name']?.toString(),
        managerName: value['manager_name']?.toString(),
        registrationNumber: value['registration_number']?.toString(),
        economicCode: value['economic_code']?.toString(),
        foundingDate: value['founding_date']?.toString(),
        secondaryPhone: value['secondary_phone']?.toString(),
        creditLimit: (value['credit_limit'] as num?)?.toDouble(),
        cardNumber: value['card_number']?.toString(),
        accountHolder: value['account_holder']?.toString(),
        region: value['region']?.toString(),
        neighborhood: value['neighborhood']?.toString(),
        plaque: value['plaque']?.toString(),
        unit: value['unit']?.toString(),
        latitude: (value['latitude'] as num?)?.toDouble(),
        longitude: (value['longitude'] as num?)?.toDouble(),
        description: value['description']?.toString(),
        openingBalance: (value['opening_balance'] as num?)?.toDouble(),
        balanceType: value['balance_type']?.toString(),
        detailGroups: (value['detail_groups'] as List? ?? const [])
            .map((e) => e.toString())
            .toSet(),
        employeeRoles: (value['employee_roles'] as List? ?? const [])
            .map((e) => e.toString())
            .toSet(),
        disabled: value['disabled'] == true,
      );

  PartyProfile _copyProfile(PartyProfile value,
          {Set<String>? detailGroups, bool? disabled}) =>
      PartyProfile(
        id: value.id,
        company: value.company,
        kind: value.kind,
        displayName: value.displayName,
        roles: value.roles,
        nationalId: value.nationalId,
        mobile: value.mobile,
        phone: value.phone,
        email: value.email,
        website: value.website,
        province: value.province,
        city: value.city,
        address: value.address,
        postalCode: value.postalCode,
        bankName: value.bankName,
        iban: value.iban,
        accountNumber: value.accountNumber,
        birthDate: value.birthDate,
        employeeGender: value.employeeGender,
        dateOfJoining: value.dateOfJoining,
        fatherName: value.fatherName,
        birthCertificateNumber: value.birthCertificateNumber,
        birthCertificateIssuePlace: value.birthCertificateIssuePlace,
        employmentType: value.employmentType,
        jobTitle: value.jobTitle,
        department: value.department,
        aliasName: value.aliasName,
        managerName: value.managerName,
        registrationNumber: value.registrationNumber,
        economicCode: value.economicCode,
        foundingDate: value.foundingDate,
        secondaryPhone: value.secondaryPhone,
        creditLimit: value.creditLimit,
        cardNumber: value.cardNumber,
        accountHolder: value.accountHolder,
        region: value.region,
        neighborhood: value.neighborhood,
        plaque: value.plaque,
        unit: value.unit,
        latitude: value.latitude,
        longitude: value.longitude,
        description: value.description,
        openingBalance: value.openingBalance,
        balanceType: value.balanceType,
        employeeRoles: value.employeeRoles,
        detailGroups: detailGroups ?? value.detailGroups,
        floatingDetails: value.floatingDetails,
        disabled: disabled ?? value.disabled,
      );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
