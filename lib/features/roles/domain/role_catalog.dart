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
      this.assignedUsers = 0});
  factory ManagedRole.fromJson(Map<String, dynamic> json) => ManagedRole(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      baseRoles: (json['base_roles'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      parent: json['parent']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] == true || json['enabled'] == 1,
      modified: json['modified']?.toString(),
      profileModified: json['profile_modified']?.toString(),
      assignedUsers: (json['assigned_users'] as num?)?.toInt() ?? 0);
  final String code, title, category, parent, description;
  final List<String> baseRoles;
  final bool enabled;
  final String? modified, profileModified;
  final int assignedUsers;
  Map<String, dynamic> toJson() => {
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
      this.templateCategories = const []});
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
            parse('template_categories', RoleCategory.fromJson));
  }
  final List<RoleCategory> categories, templateCategories;
  final List<ManagedRole> roles;
  final List<BaseAccessRole> baseRoles;
  final List<AccessRoleTemplate> templates;
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
