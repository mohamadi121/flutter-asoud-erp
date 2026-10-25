import 'dart:convert';

import 'package:asoud_erp/main.dart' as app;
import 'package:asoud_erp/features/hr/presentation/pages/organization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

// Run only on a disposable test company. The configured path contains real
// native Department IDs, root first, with each child on its parent's first page.
// No credentials or site-specific IDs are committed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const company = String.fromEnvironment('ASOUD_E2E_ORG_COMPANY');
  const pathJson = String.fromEnvironment('ASOUD_E2E_ORG_PATH');
  testWidgets('real inline position create, reload and safe delete', (tester) async {
    app.main();
    await waitFor(tester, find.byKey(const Key('username_field')));
    await tester.enterText(find.widgetWithText(TextField, 'نشانی سرور'), E2e.url);
    await tester.enterText(find.byKey(const Key('username_field')), E2e.user);
    await tester.enterText(find.byKey(const Key('password_field')), E2e.password);
    await tapVisible(tester, find.byKey(const Key('login_button')));
    await waitFor(tester, find.text('خانه'));
    final context = tester.element(find.text('خانه').first);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const OrganizationPage(company: company),
    )).ignore();
    final path = List<String>.from(jsonDecode(pathJson) as List);
    for (final id in path) {
      await tapVisible(tester, find.byKey(ValueKey('focus-unit-$id')));
    }
    await tapVisible(tester, find.text('جایگاه جدید'));
    final title = 'آزمون جایگاه ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byKey(const ValueKey('focus-editor-title')), title);
    await tapVisible(tester, find.text('ذخیره').last);
    await waitFor(tester, find.text('تغییرات ذخیره شد.'));
    await tapVisible(tester, find.byTooltip('بازخوانی ساختار و تصاویر'));
    await waitFor(tester, find.text(title));
    expect(find.byKey(ValueKey('focus-unit-${path.last}')), findsOneWidget);
    await tapVisible(tester, find.byTooltip('عملیات $title'));
    await tapVisible(tester, find.text('حذف ایمن جایگاه'));
    await tapVisible(tester, find.text('حذف با تأیید نهایی'));
    await tapVisible(tester, find.text('تأیید حذف').last);
    await waitFor(tester, find.text('تغییرات ذخیره شد.'));
    await tapVisible(tester, find.byTooltip('بازخوانی ساختار و تصاویر'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  }, skip: E2e.skipReason != null || company.isEmpty || pathJson.isEmpty,
      timeout: const Timeout(Duration(minutes: 5)));
}
