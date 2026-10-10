import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'user_access_fakes.dart';

void main() {
  testWidgets('Administrator sees the مدیریت کاربران tile and opens it',
      (tester) async {
    final client = UserAccessClient(roles: const ['Administrator']);
    await tester.pumpWidget(userAccessSettings(client));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت کاربران'), findsOneWidget);

    await tester.ensureVisible(find.text('مدیریت کاربران'));
    await tester.tap(find.text('مدیریت کاربران'));
    await tester.pumpAndSettle();

    expect(find.text('انتخاب نقش برای مدیریت دسترسی کاربران'), findsOneWidget);
    expect(
        client.calls, contains('asoud_erp.api.v1.role_management.catalog'));
    expect(find.text('مدیر منابع انسانی'), findsWidgets);
  });

  testWidgets('hr-manager does not see the مدیریت کاربران tile', (tester) async {
    final client = UserAccessClient(roles: const ['HR Manager', 'Employee']);
    await tester.pumpWidget(userAccessSettings(client));
    await tester.pumpAndSettle();

    expect(find.text('مدیریت کاربران'), findsNothing);
  });
}
