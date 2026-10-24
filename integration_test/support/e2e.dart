import 'package:flutter_test/flutter_test.dart';

abstract final class E2e {
  static const url = String.fromEnvironment('ASOUD_E2E_URL');
  static const user = String.fromEnvironment('ASOUD_E2E_USER');
  static const password = String.fromEnvironment('ASOUD_E2E_PASSWORD');
  static String? get skipReason => url.isEmpty || user.isEmpty || password.isEmpty
      ? 'اجرا نشد: ASOUD_E2E_URL، ASOUD_E2E_USER و ASOUD_E2E_PASSWORD را با --dart-define تعیین کنید.'
      : null;
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
