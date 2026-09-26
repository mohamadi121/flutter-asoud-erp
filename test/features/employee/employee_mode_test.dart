import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/employee/domain/employee_mode.dart';
import 'package:flutter_test/flutter_test.dart';

FrappeUserContext _user(List<String> roles, {String? employee = 'HR-EMP-1'}) =>
    FrappeUserContext(
        userId: 'u@example.com',
        fullName: 'User',
        roles: roles,
        employeeId: employee,
        company: 'Tabaan');

void main() {
  test('a plain employee gets the employee panel', () {
    expect(isEmployeeOnly(_user(const ['Employee'])), isTrue);
    expect(isEmployeeOnly(_user(const ['Employee', 'Leave Approver'])), isTrue);
  });

  test('managers and users without an employee keep the office dashboard', () {
    expect(isEmployeeOnly(_user(const ['Employee'], employee: null)), isFalse);
    for (final role in managerRoles) {
      expect(isEmployeeOnly(_user(['Employee', role])), isFalse, reason: role);
    }
  });
}
