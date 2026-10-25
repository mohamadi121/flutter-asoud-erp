class RoleCategory {
  const RoleCategory(
      {required this.code, required this.title, required this.style});
  factory RoleCategory.fromJson(Map<String, dynamic> json) => RoleCategory(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      style: json['style']?.toString() ?? 'system');
  final String code, title, style;
}

class ManagedRole {
  const ManagedRole(
      {required this.code,
      required this.title,
      required this.category,
      required this.baseRoles,
      this.parent = '',
      this.description = '',
      this.enabled = true,
      this.modified,
      this.profileModified,
      this.assignedUsers = 0,
      this.scope = '',
      this.system = false,
      this.scopeTitle = '',
      this.nativeRole = '',
      this.holders = const []});
  factory ManagedRole.fromJson(Map<String, dynamic> json) => ManagedRole(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      baseRoles: (json['base_roles'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          [
            if ('${json['native_role'] ?? ''}'.isNotEmpty)
              '${json['native_role']}'
          ],
      parent: json['parent']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] == true || json['enabled'] == 1,
      modified: json['modified']?.toString(),
      profileModified: json['profile_modified']?.toString(),
      assignedUsers: (json['assigned_users'] as num?)?.toInt() ?? 0,
      scope: json['scope']?.toString() ?? '',
      system: json['system'] == true || json['system'] == 1,
      scopeTitle: json['scope_title']?.toString() ?? '',
      nativeRole: json['native_role']?.toString() ?? '',
      holders: (json['holders'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const []);
  final String code, title, category, parent, description;
  final List<String> baseRoles;
  final bool enabled;
  final String? modified, profileModified;
  final int assignedUsers;

  /// `global` for organisation-wide roles such as «مدیر کل سیستم».
  final String scope;

  /// Protected system role: shown and inspectable, never edited here.
  final bool system;
  bool get isGlobal => scope == 'global';

  /// `scope_title` of the system row («سراسری»), else derived from [scope].
  String get scopeLabel => scopeTitle.isNotEmpty
      ? scopeTitle
      : scope == 'global'
          ? 'سراسری'
          : scope == 'office'
              ? 'مخصوص دفتر'
              : '';

  /// The native role behind a system row (`System Manager`).
  final String scopeTitle, nativeRole;

  /// Accounts currently holding a system role (`holders`).
  final List<String> holders;

  /// «مدیر کل سیستم»: the protected, global, non-editable row of
  /// `catalog.system_roles`.
  bool get isSystemAdmin => system && code == 'SYSTEM_ADMIN';
  Map<String, dynamic> toJson() => {
        if (scope.isNotEmpty) 'scope': scope,
        'code': code,
        'title': title,
        'category': category,
        'parent': parent,
        'description': description,
        'enabled': enabled ? 1 : 0,
        'base_roles': baseRoles,
        'modified': modified,
        'profile_modified': profileModified,
      };
}

class BaseAccessRole {
  const BaseAccessRole(
      {required this.name,
      required this.title,
      required this.description,
      required this.available});
  factory BaseAccessRole.fromJson(Map<String, dynamic> json) => BaseAccessRole(
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      available: json['available'] == true || json['available'] == 1);
  final String name, title, description;
  final bool available;
}

class AccessRoleTemplate {
  const AccessRoleTemplate(
      {required this.code,
      required this.title,
      required this.category,
      required this.baseRoles,
      required this.available,
      required this.exists});
  factory AccessRoleTemplate.fromJson(Map<String, dynamic> json) =>
      AccessRoleTemplate(
          code: json['code']?.toString() ?? '',
          title: json['title']?.toString() ?? '',
          category: json['category']?.toString() ?? '',
          baseRoles: (json['base_roles'] as List?)
                  ?.map((e) => e.toString())
                  .toList(growable: false) ??
              const [],
          available: json['available'] == true || json['available'] == 1,
          exists: json['exists'] == true || json['exists'] == 1);
  final String code, title, category;
  final List<String> baseRoles;
  final bool available, exists;
}

class RoleCatalog {
  const RoleCatalog(
      {this.categories = const [],
      this.roles = const [],
      this.baseRoles = const [],
      this.templates = const [],
      this.templateCategories = const [],
      this.systemRoles = const []});
  factory RoleCatalog.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) decode) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map>()
            .map((row) => decode(Map<String, dynamic>.from(row)))
            .toList();
    return RoleCatalog(
        categories: parse('categories', RoleCategory.fromJson),
        roles: parse('roles', ManagedRole.fromJson),
        baseRoles: parse('base_roles', BaseAccessRole.fromJson),
        templates: parse('templates', AccessRoleTemplate.fromJson),
        templateCategories:
            parse('template_categories', RoleCategory.fromJson),
        systemRoles: parse('system_roles', ManagedRole.fromJson));
  }
  final List<RoleCategory> categories, templateCategories;
  final List<ManagedRole> roles;
  final List<BaseAccessRole> baseRoles;
  final List<AccessRoleTemplate> templates;

  /// `catalog.system_roles`: protected rows such as «مدیر کل سیستم».
  final List<ManagedRole> systemRoles;
}

/// One ASOUD capability row of `role_management.system_admin_permissions`
/// (`{key, module, title, gate, granted}`).
class RoleCapability {
  const RoleCapability(
      {required this.key,
      required this.module,
      required this.title,
      required this.granted});
  factory RoleCapability.fromJson(Map<String, dynamic> json) => RoleCapability(
      key: json['key']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      granted: json['granted'] == true);
  final String key, module, title;
  final bool granted;
}

/// `role_management.system_admin_permissions`: the administrator row plus the
/// complete permission list (every DocType right of System Manager, and the
/// ASOUD capabilities).
class SystemAdminPermissions {
  const SystemAdminPermissions(
      {required this.role,
      this.capabilities = const [],
      this.documents = const []});
  factory SystemAdminPermissions.fromJson(Map<String, dynamic> json) =>
      SystemAdminPermissions(
          role: ManagedRole.fromJson(json),
          capabilities: ((json['capabilities'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => RoleCapability.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          documents: ((json['document_permissions'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => RolePermissionRow(
                  doctype: e['doctype']?.toString() ?? '',
                  role: 'System Manager',
                  level: 0,
                  ownerOnly: false,
                  actions: ((e['actions'] as List?) ?? const [])
                      .map((a) => a.toString())
                      .toList()))
              .toList());
  final ManagedRole role;
  final List<RoleCapability> capabilities;
  final List<RolePermissionRow> documents;
}

class RolePermissionRow {
  const RolePermissionRow(
      {required this.doctype,
      required this.role,
      required this.level,
      required this.ownerOnly,
      required this.actions});
  factory RolePermissionRow.fromJson(Map<String, dynamic> json) =>
      RolePermissionRow(
          doctype: json['doctype']?.toString() ?? '',
          role: json['role']?.toString() ?? '',
          level: (json['level'] as num?)?.toInt() ?? 0,
          ownerOnly: json['owner_only'] == true || json['owner_only'] == 1,
          actions: (json['actions'] as List?)
                  ?.map((e) => e.toString())
                  .toList(growable: false) ??
              const []);
  final String doctype, role;
  final int level;
  final bool ownerOnly;
  final List<String> actions;
}

/// One row of `role_access.list_office_roles`.
class OfficeRoleAssignment {
  const OfficeRoleAssignment(
      {required this.company,
      required this.role,
      this.grantedBy = '',
      this.grantedOn = ''});
  factory OfficeRoleAssignment.fromJson(Map<String, dynamic> json) =>
      OfficeRoleAssignment(
          company: json['company']?.toString() ?? '',
          role: json['role']?.toString() ?? '',
          grantedBy: json['granted_by']?.toString() ?? '',
          grantedOn: json['granted_on']?.toString() ?? '');
  final String company, role, grantedBy, grantedOn;
}

/// What `role_access.assign_role` / `unassign_role` answer:
/// `{user, role, scope, company, assigned | removed, already_assigned}`.
class RoleAssignmentResult {
  const RoleAssignmentResult(
      {required this.user,
      required this.role,
      this.scope = '',
      this.company,
      this.assigned = false,
      this.removed = false,
      this.alreadyAssigned = false});
  factory RoleAssignmentResult.fromJson(Map<String, dynamic> json) {
    final company = '${json['company'] ?? ''}'.trim();
    return RoleAssignmentResult(
        user: json['user']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        scope: json['scope']?.toString() ?? '',
        company: company.isEmpty ? null : company,
        assigned: json['assigned'] == true,
        removed: json['removed'] == true,
        alreadyAssigned: json['already_assigned'] == true);
  }
  final String user, role, scope;
  final String? company;
  final bool assigned, removed, alreadyAssigned;
}
