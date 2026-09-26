class RoleCategory {
  const RoleCategory(
      {required this.code, required this.title, required this.style});
  factory RoleCategory.fromJson(Map<String, dynamic> json) => RoleCategory(
      code: json['code'] as String,
      title: json['title'] as String,
      style: json['style'] as String);
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
      code: json['code'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      baseRoles: List<String>.from(json['base_roles'] as List),
      parent: json['parent'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] == true,
      modified: json['modified'] as String?,
      profileModified: json['profile_modified'] as String?,
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
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      available: json['available'] == true);
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
          code: json['code'] as String,
          title: json['title'] as String,
          category: json['category'] as String,
          baseRoles: List<String>.from(json['base_roles'] as List),
          available: json['available'] == true,
          exists: json['exists'] == true);
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
        (json[key] as List)
            .map((row) => decode(Map<String, dynamic>.from(row as Map)))
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
          doctype: json['doctype'] as String,
          role: json['role'] as String,
          level: (json['level'] as num).toInt(),
          ownerOnly: json['owner_only'] == true,
          actions: List<String>.from(json['actions'] as List));
  final String doctype, role;
  final int level;
  final bool ownerOnly;
  final List<String> actions;
}
