import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'user_access_fakes.dart';

void main() {
  testWidgets('network failure shows a retry button', (tester) async {
    await tester.pumpWidget(userAccessApp(UserAccessPage(
        role: userAccessRole,
        repository: UserAccessRepository(UserAccessClient(mode: 'network')))));
    await tester.pumpAndSettle();
    expect(find.text('دریافت اطلاعات ناموفق بود'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('forbidden failure shows no retry button', (tester) async {
    await tester.pumpWidget(userAccessApp(UserAccessPage(
        role: userAccessRole,
        repository:
            UserAccessRepository(UserAccessClient(mode: 'forbidden')))));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی محدود است'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('UserAccessPage fits and works at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = UserAccessClient();
      await tester.pumpWidget(userAccessApp(UserAccessPage(
          role: userAccessRole, repository: UserAccessRepository(client))));
      await tester.pumpAndSettle();

      expect(find.text('کاربر نمونه'), findsOneWidget);

      await tester.tap(find.text('کاربر نمونه'));
      await tester.pumpAndSettle();
      expect(find.text('تعیین نقش و دسترسی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
