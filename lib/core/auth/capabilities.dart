import '../network/frappe_client.dart';

/// Client-side presentation policy for authoritative ERPNext roles.
///
/// Server endpoints still enforce these permissions. This object only prevents
/// controls that the signed-in user cannot use from being rendered.
class Capabilities {
  const Capabilities._({
    required this.canManageWorkflows,
    required this.canManageRequestTypes,
    required this.canManageRoles,
    required this.canManageOrganization,
    required this.canManageDocumentTemplates,
    required this.canWritePersonnel,
    required this.canManageUserAccess,
    required this.canWriteHrRecords,
    required this.canSeeAccounting,
    required this.canSeeSettingsAdmin,
    required this.canReadManagerViews,
  });

  factory Capabilities.fromRoles(
    Iterable<String> roles, {
    bool offlinePreview = false,
  }) {
    if (offlinePreview) return full;
    final names = roles.map((role) => role.trim()).toSet();
    final system = names.contains('System Manager');
    final accountsManager = names.contains('Accounts Manager');
    final accountsUser = names.contains('Accounts User');
    final purchaseManager = names.contains('Purchase Manager');
    final hrManager = names.contains('HR Manager');
    final configurationWriter = system || accountsManager;

    return Capabilities._(
      canManageWorkflows: configurationWriter,
      canManageRequestTypes: configurationWriter,
      canManageRoles: system,
      canManageOrganization: configurationWriter,
      canManageDocumentTemplates: system || accountsManager || purchaseManager,
      canWritePersonnel: system,
      canManageUserAccess: system,
      canWriteHrRecords: system,
      canSeeAccounting: system || accountsManager || accountsUser,
      canSeeSettingsAdmin: configurationWriter,
      canReadManagerViews:
          system || accountsManager || accountsUser || hrManager,
    );
  }

  static const full = Capabilities._(
    canManageWorkflows: true,
    canManageRequestTypes: true,
    canManageRoles: true,
    canManageOrganization: true,
    canManageDocumentTemplates: true,
    canWritePersonnel: true,
    canManageUserAccess: true,
    canWriteHrRecords: true,
    canSeeAccounting: true,
    canSeeSettingsAdmin: true,
    canReadManagerViews: true,
  );

  final bool canManageWorkflows;
  final bool canManageRequestTypes;
  final bool canManageRoles;
  final bool canManageOrganization;
  final bool canManageDocumentTemplates;
  final bool canWritePersonnel;
  final bool canManageUserAccess;
  final bool canWriteHrRecords;
  final bool canSeeAccounting;
  final bool canSeeSettingsAdmin;
  final bool canReadManagerViews;
}

Future<Capabilities> loadCapabilities(
  FrappeApiClient client, {
  bool offlinePreview = false,
}) async {
  if (offlinePreview || !client.isAuthenticated) return Capabilities.full;
  final user = await client.getCurrentUser();
  return Capabilities.fromRoles(user.roles);
}
