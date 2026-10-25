import 'package:equatable/equatable.dart';

/// One accessible office of `session.login_state.offices`
/// (`{id, title, office_type, roles[], office_roles[]}`).
class OfficeRef extends Equatable {
  const OfficeRef({
    required this.name,
    required this.title,
    this.officeType = '',
    this.roles = const [],
    this.officeRoles = const [],
  });

  factory OfficeRef.fromJson(Map<String, dynamic> json) {
    final name = '${json['id'] ?? ''}'.trim();
    final title = '${json['title'] ?? ''}'.trim();
    List<String> list(Object? value) => value is List
        ? value.map((e) => '$e').toList(growable: false)
        : const <String>[];
    return OfficeRef(
      name: name,
      title: title.isEmpty ? name : title,
      officeType: '${json['office_type'] ?? ''}',
      roles: list(json['roles']),
      officeRoles: list(json['office_roles']),
    );
  }

  /// The office (company) id, `offices[].id`.
  final String name;
  final String title;
  final String officeType;

  /// Effective roles held in this office (global + office-scoped).
  final List<String> roles;

  /// Roles that were assigned for this office only.
  final List<String> officeRoles;

  @override
  List<Object?> get props => [name, title, officeType, roles, officeRoles];
}

/// Identity fields of the signed-in account. Built from `login_state.user`
/// and, for the administrator form, from `onboarding.get_admin_profile`.
class AccountProfile extends Equatable {
  const AccountProfile({
    this.username = '',
    this.firstName = '',
    this.lastName = '',
    this.mobile = '',
    this.nationalId = '',
    this.email = '',
    this.active = true,
    this.roleLabel = '',
    this.mobileVerified = false,
    this.emailVerified = false,
  });

  /// `session.login_state.user`.
  factory AccountProfile.fromUser(Map<String, dynamic> json) => AccountProfile(
        username: '${json['id'] ?? ''}',
        firstName: '${json['first_name'] ?? ''}',
        lastName: '${json['last_name'] ?? ''}',
        mobile: '${json['mobile'] ?? ''}',
        email: '${json['email'] ?? ''}',
      );

  /// `onboarding.get_admin_profile` / `save_admin_profile` data.
  factory AccountProfile.fromAdminProfile(Map<String, dynamic> json) =>
      AccountProfile(
        username: '${json['username'] ?? ''}',
        firstName: '${json['first_name'] ?? ''}',
        lastName: '${json['last_name'] ?? ''}',
        mobile: '${json['mobile'] ?? ''}',
        nationalId: '${json['national_id'] ?? ''}',
        email: '${json['email'] ?? ''}',
        active: json['active'] != false && json['active'] != 0,
        roleLabel: '${json['role'] ?? ''}',
        mobileVerified: json['mobile_verified'] == true,
        emailVerified: json['email_verified'] == true,
      );

  final String username;
  final String firstName;
  final String lastName;
  final String mobile;
  final String nationalId;
  final String email;
  final bool active;
  final String roleLabel;
  final bool mobileVerified;
  final bool emailVerified;

  @override
  List<Object?> get props => [
        username,
        firstName,
        lastName,
        mobile,
        nationalId,
        email,
        active,
        roleLabel,
        mobileVerified,
        emailVerified,
      ];
}

/// `login_state.next`: the server's own decision of the screen to open.
class NextRoute extends Equatable {
  const NextRoute({required this.route, this.office, this.message});

  factory NextRoute.fromJson(Map<String, dynamic> json) {
    final office = '${json['office'] ?? ''}'.trim();
    final message = '${json['message'] ?? ''}'.trim();
    return NextRoute(
      route: '${json['route'] ?? ''}'.trim(),
      office: office.isEmpty ? null : office,
      message: message.isEmpty ? null : message,
    );
  }

  /// `account-disabled | change-password | create-first-office |
  /// complete-admin-profile | office-select | home | no-office`.
  final String route;
  final String? office;
  final String? message;

  @override
  List<Object?> get props => [route, office, message];
}

/// The server's answer to "where does this account go after sign-in"
/// (`asoud_erp.api.v1.session.login_state`). The client never derives
/// administrator rights from "first login"; every flag below is computed by
/// the server.
class LoginState extends Equatable {
  const LoginState({
    required this.userId,
    this.fullName = '',
    this.accountActive = true,
    this.mustChangePassword = false,
    this.temporaryPasswordExpired = false,
    this.isSystemAdmin = false,
    this.roleTitle = '',
    this.scope = 'office',
    this.canCreateOffice = false,
    this.canManageRoles = false,
    this.canDelegateRoles = false,
    this.canRegisterPersonnel = false,
    this.firstOfficeExists = false,
    this.adminProfileComplete = false,
    this.mobileVerified = false,
    this.emailVerified = false,
    this.offices = const [],
    this.selectedOffice,
    this.roles = const [],
    this.profile = const AccountProfile(),
    this.next,
  });

  factory LoginState.fromJson(Map<String, dynamic> json) {
    bool flag(Object? value, [bool fallback = false]) {
      if (value == null) return fallback;
      return value == true || value == 1 || value == '1';
    }

    Map<String, dynamic> map(Object? value) =>
        value is Map ? Map<String, dynamic>.from(value) : const {};

    final rawOffices = json['offices'];
    final offices = rawOffices is List
        ? rawOffices
            .whereType<Map>()
            .map((row) => OfficeRef.fromJson(Map<String, dynamic>.from(row)))
            .where((office) => office.name.isNotEmpty)
            .toList(growable: false)
        : const <OfficeRef>[];
    final selected = '${json['selected_office'] ?? ''}'.trim();
    final user = map(json['user']);
    final account = map(json['account']);
    final caps = map(json['capabilities']);
    final verification = map(json['verification']);
    final roles = json['roles'];
    final next = map(json['next']);
    return LoginState(
      userId: '${user['id'] ?? ''}',
      fullName: '${user['full_name'] ?? ''}',
      accountActive: flag(account['active'], true),
      mustChangePassword: flag(account['must_change_password']),
      temporaryPasswordExpired: flag(account['temporary_password_expired']),
      isSystemAdmin: flag(json['is_system_admin']),
      roleTitle: '${json['role_title'] ?? ''}',
      scope: '${json['scope'] ?? 'office'}',
      canCreateOffice: flag(caps['create_office']),
      canManageRoles: flag(caps['manage_roles']),
      canDelegateRoles: flag(caps['delegate_roles']),
      canRegisterPersonnel: flag(caps['register_personnel']),
      firstOfficeExists: flag(json['first_office_exists']),
      adminProfileComplete: flag(json['admin_profile_complete']),
      mobileVerified: flag(verification['mobile_verified']),
      emailVerified: flag(verification['email_verified']),
      offices: offices,
      selectedOffice: selected.isEmpty ? null : selected,
      roles: roles is List
          ? roles.map((role) => '$role').toList(growable: false)
          : const [],
      profile: AccountProfile.fromUser(user),
      next: next.isEmpty ? null : NextRoute.fromJson(next),
    );
  }

  final String userId;
  final String fullName;
  final bool accountActive;
  final bool mustChangePassword;
  final bool temporaryPasswordExpired;
  final bool isSystemAdmin;

  /// «مدیر کل سیستم» for the administrator, empty otherwise.
  final String roleTitle;

  /// `global` (administrator) or `office`.
  final String scope;
  final bool canCreateOffice;
  final bool canManageRoles;
  final bool canDelegateRoles;
  final bool canRegisterPersonnel;
  final bool firstOfficeExists;
  final bool adminProfileComplete;
  final bool mobileVerified;
  final bool emailVerified;
  final List<OfficeRef> offices;
  final String? selectedOffice;
  final List<String> roles;
  final AccountProfile profile;

  /// The server's routing decision; null only for hand-built states in
  /// previews, where [decideLoginRoute] falls back to the local rule.
  final NextRoute? next;

  @override
  List<Object?> get props => [
        userId,
        fullName,
        accountActive,
        mustChangePassword,
        temporaryPasswordExpired,
        isSystemAdmin,
        roleTitle,
        scope,
        canCreateOffice,
        canManageRoles,
        canDelegateRoles,
        canRegisterPersonnel,
        firstOfficeExists,
        adminProfileComplete,
        mobileVerified,
        emailVerified,
        offices,
        selectedOffice,
        roles,
        profile,
        next,
      ];
}
