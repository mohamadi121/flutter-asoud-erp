import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    required this.canReadRoleCatalog,
    required this.canReadOrganization,
  });

  factory Capabilities.fromRoles(
    Iterable<String> roles, {
    bool offlinePreview = false,
  }) {
    if (offlinePreview) return full;
    final names = roles.map((role) => role.trim()).toSet();
    final system =
        names.contains('System Manager') || names.contains('Administrator');
    final accountsManager = names.contains('Accounts Manager');
    final accountsUser = names.contains('Accounts User');
    final purchaseManager = names.contains('Purchase Manager');
    final hrManager = names.contains('HR Manager');
    final hrUser = names.contains('HR User');
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
      canReadRoleCatalog: system || hrManager,
      canReadOrganization: system || hrManager || hrUser,
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
    canReadRoleCatalog: true,
    canReadOrganization: true,
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
  final bool canReadRoleCatalog;
  final bool canReadOrganization;
}

Future<Capabilities> loadCapabilities(
  FrappeApiClient client, {
  bool offlinePreview = false,
}) async {
  if (offlinePreview || !client.isAuthenticated) return Capabilities.full;
  final user = await client.getCurrentUser();
  return Capabilities.fromRoles(user.roles);
}

/// Resolves the capability policy from the ambient client.
///
/// Pages built without a client provider (injected repositories in tests, or a
/// preview shell) stay fully visible; any other profile failure fails closed so
/// a broken session never reveals administrative controls.
Future<Capabilities> capabilitiesOf(
  BuildContext context, {
  bool offlinePreview = false,
}) async {
  try {
    return await loadCapabilities(context.read<FrappeApiClient>(),
        offlinePreview: offlinePreview);
  } on ProviderNotFoundException {
    return Capabilities.full;
  } catch (_) {
    return Capabilities.fromRoles(const []);
  }
}
