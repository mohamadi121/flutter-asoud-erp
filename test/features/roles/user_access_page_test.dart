import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'user_access_fakes.dart';

void main() {
  testWidgets(
      'UserAccessPage shows users, opens one and translates base roles to Persian',
      (tester) async {
    final client = UserAccessClient();
    await tester.pumpWidget(userAccessApp(UserAccessPage(
        role: userAccessRole, repository: UserAccessRepository(client))));
    await tester.pumpAndSettle();

    expect(find.text('کاربر نمونه'), findsOneWidget);

    await tester.tap(find.text('کاربر نمونه'));
    await tester.pumpAndSettle();

    expect(find.text('تعیین نقش و دسترسی'), findsOneWidget);
    expect(find.text('حسابداری'), findsOneWidget);

    await tester.tap(find.text('مرحله بعد'));
    await tester.pumpAndSettle();

    expect(find.textContaining('نقش‌های پایه همراه این تخصیص: مدیر منابع انسانی'),
        findsOneWidget);
    expect(find.textContaining('HR Manager'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('apply stays disabled until the matrix actually changes',
      (tester) async {
    final client = UserAccessClient();
    await tester.pumpWidget(userAccessApp(UserAccessPage(
        role: userAccessRole, repository: UserAccessRepository(client))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('کاربر نمونه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مرحله بعد'));
    await tester.pumpAndSettle();

    final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ارسال دسترسی‌ها'));
    expect(disabled.onPressed, isNull);

    await tester.tap(find.text('ویرایش'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابداری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مرحله بعد'));
    await tester.pumpAndSettle();

    final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ارسال دسترسی‌ها'));
    expect(enabled.onPressed, isNotNull);
  });
}
