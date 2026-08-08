import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current user contract parses roles and employee context', () {
    final user = FrappeUserContext.fromJson(const {
      'user_id': 'accountant@example.com',
      'full_name': 'کاربر حسابداری',
      'roles': ['Accounts User'],
      'employee': {
        'name': 'HR-EMP-0001',
        'employee_name': 'کاربر حسابداری',
        'company': 'شرکت نمونه',
      },
    });

    expect(user.userId, 'accountant@example.com');
    expect(user.hasRole('Accounts User'), isTrue);
    expect(user.employeeId, 'HR-EMP-0001');
    expect(user.company, 'شرکت نمونه');
  });

  test('current user contract accepts a user without employee profile', () {
    final user = FrappeUserContext.fromJson(const {
      'user_id': 'Administrator',
      'full_name': 'Administrator',
      'roles': ['System Manager'],
      'employee': null,
    });

    expect(user.employeeId, isNull);
    expect(user.hasRole('System Manager'), isTrue);
  });
}
