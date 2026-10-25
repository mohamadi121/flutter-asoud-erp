import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';

/// `data.activation` of `hr_onboarding.register_personnel` /
/// `issue_temporary_password`.
///
/// * temporary password: `{method: "temporary_password", temporary_password,
///   expires_in_hours: 72, must_change_on_first_login: true, note}` (shown once)
/// * invitation: `{method: "invite", expires_in_hours: 72, sent_to}`
class PersonnelActivation {
  const PersonnelActivation({
    required this.method,
    this.temporaryPassword,
    this.expiresInHours,
    this.mustChangeOnFirstLogin = false,
    this.sentTo,
    this.note,
  });

  factory PersonnelActivation.fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final value = '${v ?? ''}'.trim();
      return value.isEmpty ? null : value;
    }

    final hours = json['expires_in_hours'];
    return PersonnelActivation(
      method: '${json['method'] ?? ''}',
      temporaryPassword: text(json['temporary_password']),
      expiresInHours: hours is num ? hours.toInt() : null,
      mustChangeOnFirstLogin: json['must_change_on_first_login'] == true,
      sentTo: text(json['sent_to']),
      note: text(json['note']),
    );
  }

  final String method;
  final String? temporaryPassword;
  final int? expiresInHours;
  final bool mustChangeOnFirstLogin;
  final String? sentTo;
  final String? note;

  bool get isTemporaryPassword => method == 'temporary_password';
}

/// `hr_onboarding.register_personnel` answer:
/// `{person, employee, user, company, reused_person, account_created, roles,
/// activation, hr_lead}`.
class PersonnelRegistration {
  const PersonnelRegistration({
    required this.person,
    this.employee,
    this.user,
    this.company = '',
    this.reusedPerson = false,
    this.accountCreated = false,
    this.roles = const [],
    this.activation,
    this.hrLead = false,
  });

  factory PersonnelRegistration.fromJson(Map<String, dynamic> json) {
    final activation = json['activation'];
    String? text(Object? v) {
      final value = '${v ?? ''}'.trim();
      return value.isEmpty ? null : value;
    }

    return PersonnelRegistration(
      person: '${json['person'] ?? ''}',
      employee: text(json['employee']),
      user: text(json['user']),
      company: '${json['company'] ?? ''}',
      reusedPerson: json['reused_person'] == true,
      accountCreated: json['account_created'] == true,
      roles: json['roles'] is List
          ? (json['roles'] as List).map((e) => '$e').toList(growable: false)
          : const [],
      activation: activation is Map
          ? PersonnelActivation.fromJson(Map<String, dynamic>.from(activation))
          : null,
      hrLead: json['hr_lead'] == true,
    );
  }

  final String person;
  final String? employee;
  final String? user;
  final String company;
  final bool reusedPerson;
  final bool accountCreated;
  final List<String> roles;
  final PersonnelActivation? activation;
  final bool hrLead;
}

/// Calls of `asoud_erp.api.v1.hr_onboarding`. Online only (`callMethod`): a
/// one-time temporary password must never sit in the offline queue.
class HrOnboardingRepository {
  HrOnboardingRepository(this.client);
  final FrappeApiClient client;

  static const _base = 'asoud_erp.api.v1.hr_onboarding';

  Future<Map<String, dynamic>> _call(String method,
      Map<String, dynamic> data) async {
    final body = await client.callMethod('$_base.$method', data: data);
    final envelope = body['message'];
    final result = envelope is Map ? envelope['data'] : null;
    if (envelope is! Map || envelope['ok'] != true || result is! Map) {
      throw const ApiException.protocol();
    }
    return Map<String, dynamic>.from(result);
  }

  /// `register_personnel`: person -> personnel file -> account -> roles ->
  /// activation (`invite` needs outgoing e-mail on the server, else the server
  /// answers with a Persian error).
  Future<PersonnelRegistration> register({
    required String company,
    required String firstName,
    required String lastName,
    required String mobile,
    required String email,
    String? nationalId,
    String? gender,
    String? birthDate,
    String? dateOfJoining,
    String? jobTitle,
    String? department,
    List<String> roles = const [],
    String activation = 'invite',
    String? requestId,
  }) async =>
      PersonnelRegistration.fromJson(await _call('register_personnel', {
        'company': company,
        'first_name': firstName,
        'last_name': lastName,
        'mobile': mobile,
        'email': email,
        if (nationalId != null) 'national_id': nationalId,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birth_date': birthDate,
        if (dateOfJoining != null) 'date_of_joining': dateOfJoining,
        if (jobTitle != null) 'job_title': jobTitle,
        if (department != null) 'department': department,
        if (roles.isNotEmpty) 'roles': roles,
        'activation': activation,
        if (requestId != null) 'request_id': requestId,
      }));

  /// `issue_temporary_password(party_profile)`: a new temporary password,
  /// valid 72 hours, shown once.
  Future<PersonnelActivation> issueTemporaryPassword(
          String partyProfile) async =>
      PersonnelActivation.fromJson(
          await _call('issue_temporary_password', {'party_profile': partyProfile}));
}
