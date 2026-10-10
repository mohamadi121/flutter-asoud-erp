import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Capabilities.fromRoles', () {
    test('Administrator demo roles receive all capabilities', () {
      final capabilities = Capabilities.fromRoles(const [
        'System Manager',
        'Accounts Manager',
        'HR Manager',
        'Employee',
      ]);

      expect(capabilities.canManageWorkflows, isTrue);
      expect(capabilities.canManageRequestTypes, isTrue);
      expect(capabilities.canManageRoles, isTrue);
      expect(capabilities.canManageOrganization, isTrue);
      expect(capabilities.canManageDocumentTemplates, isTrue);
      expect(capabilities.canWritePersonnel, isTrue);
      expect(capabilities.canManageUserAccess, isTrue);
      expect(capabilities.canWriteHrRecords, isTrue);
      expect(capabilities.canSeeAccounting, isTrue);
      expect(capabilities.canSeeSettingsAdmin, isTrue);
    });

    test('the server Administrator role alone grants every capability', () {
      final capabilities = Capabilities.fromRoles(const ['Administrator']);

      expect(capabilities.canManageWorkflows, isTrue);
      expect(capabilities.canManageRoles, isTrue);
      expect(capabilities.canWritePersonnel, isTrue);
      expect(capabilities.canSeeSettingsAdmin, isTrue);
      expect(capabilities.canReadRoleCatalog, isTrue);
      expect(capabilities.canReadOrganization, isTrue);
    });

    test('HR Manager demo roles retain no administrative write capability', () {
      final capabilities =
          Capabilities.fromRoles(const ['HR Manager', 'Employee']);

      expect(capabilities.canManageWorkflows, isFalse);
      expect(capabilities.canManageRequestTypes, isFalse);
      expect(capabilities.canManageRoles, isFalse);
      expect(capabilities.canManageOrganization, isFalse);
      expect(capabilities.canManageDocumentTemplates, isFalse);
      expect(capabilities.canWritePersonnel, isFalse);
      expect(capabilities.canManageUserAccess, isFalse);
      expect(capabilities.canWriteHrRecords, isFalse);
      expect(capabilities.canSeeAccounting, isFalse);
      expect(capabilities.canSeeSettingsAdmin, isFalse);
      expect(capabilities.canReadManagerViews, isTrue);
      expect(capabilities.canReadRoleCatalog, isTrue);
      expect(capabilities.canReadOrganization, isTrue);
    });

    test('Employee-only demo roles receive no manager capability', () {
      final capabilities = Capabilities.fromRoles(const ['Employee']);

      expect(capabilities.canManageWorkflows, isFalse);
      expect(capabilities.canManageRequestTypes, isFalse);
      expect(capabilities.canManageRoles, isFalse);
      expect(capabilities.canManageOrganization, isFalse);
      expect(capabilities.canManageDocumentTemplates, isFalse);
      expect(capabilities.canWritePersonnel, isFalse);
      expect(capabilities.canManageUserAccess, isFalse);
      expect(capabilities.canWriteHrRecords, isFalse);
      expect(capabilities.canSeeAccounting, isFalse);
      expect(capabilities.canSeeSettingsAdmin, isFalse);
      expect(capabilities.canReadManagerViews, isFalse);
      expect(capabilities.canReadRoleCatalog, isFalse);
      expect(capabilities.canReadOrganization, isFalse);
    });

    test('offline preview keeps every capability visible', () {
      final capabilities = Capabilities.fromRoles(
        const ['Employee'],
        offlinePreview: true,
      );

      expect(capabilities.canManageRoles, isTrue);
      expect(capabilities.canWritePersonnel, isTrue);
      expect(capabilities.canWriteHrRecords, isTrue);
    });
  });
}
