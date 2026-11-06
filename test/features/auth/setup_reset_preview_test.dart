import 'package:asoud_erp/features/auth/data/setup_reset_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'reads the documented access blocker lists without exposing native roles',
      () {
    final details = SetupResetPreviewDetails.fromJson({
      'blocking_users': ['outside@example.test'],
      'blocking_roles': [
        {
          'user': 'outside@example.test',
          'role': 'نقش خرید',
          'native_role': 'ASOUD-ACCESS-USER-internal',
        },
      ],
    });
    expect(details.users, ['outside@example.test']);
    expect(details.roles.single.user, 'outside@example.test');
    expect(details.roles.single.label, 'نقش خرید');
    expect(details.hasBlockers, isTrue);
  });

  test('missing, null and malformed lists are safe on older servers', () {
    for (final payload in <Map<String, dynamic>>[
      {},
      {'blocking_users': null, 'blocking_roles': null},
      {'blocking_users': 'bad', 'blocking_roles': {}},
      {
        'blocking_users': [null, 3, {}],
        'blocking_roles': [null, 3]
      },
    ]) {
      final details = SetupResetPreviewDetails.fromJson(payload);
      expect(details.users, isEmpty);
      expect(details.roles, isEmpty);
      expect(details.hasBlockers, isFalse);
    }
  });

  test('technical role and user ids use Persian fallbacks', () {
    final details = SetupResetPreviewDetails.fromJson({
      'blocking_users': ['SYS-USER-1'],
      'blocking_roles': [
        {'user': 'SYS-USER-1', 'role': 'SYS-ROLE-1'},
        {'user': 'outside@example.test', 'role': 'HR Manager'},
      ],
    });
    expect(details.users, ['حساب کاربری وابسته']);
    expect(details.roles.first.label, 'نقش اختصاصی');
    expect(details.roles.first.user, 'حساب کاربری وابسته');
    expect(details.roles.last.label, 'مدیر منابع انسانی');
  });
}
