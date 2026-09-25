import '../../../core/network/frappe_client.dart';

/// Roles that keep the office dashboard instead of the employee panel.
const managerRoles = {
  'System Manager',
  'Administrator',
  'Accounts Manager',
  'Accounts User',
  'HR Manager',
  'HR User',
  'Sales Manager',
  'Purchase Manager',
  'Stock Manager',
};

/// A user linked to an Employee without any management role sees their own panel.
bool isEmployeeOnly(FrappeUserContext user) =>
    user.employeeId != null && !user.roles.any(managerRoles.contains);
