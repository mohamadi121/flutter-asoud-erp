import 'package:asoud_erp/main.dart' as app;
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/request_flow_pages.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_field_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(E2e.skipReason ?? 'ورود، ثبت درخواست مرخصی و خروج', (tester) async {
    app.main();
    await waitFor(tester, find.byKey(const Key('username_field')));
    await tester.enterText(find.widgetWithText(TextField, 'نشانی سرور'), E2e.url);
    await tester.enterText(find.byKey(const Key('username_field')), E2e.user);
    await tester.enterText(find.byKey(const Key('password_field')), E2e.password);
    await tapVisible(tester, find.byKey(const Key('login_button')));
    await waitFor(tester, find.text('خانه'));
    await tapVisible(tester, find.text('ثبت درخواست'));
    await tapVisible(tester, find.text('درخواست جدید'));
    await tapVisible(tester,
        find.byKey(const Key('new-request-module-منابع انسانی')));
    await tapVisible(tester, find.text('درخواست مرخصی'));

    Finder field(String name) => find.byWidgetPredicate(
        (widget) => widget is RequestFieldWidget && widget.field.key == name);
    await waitFor(tester, field('leave_type'));
    final controller = tester.widget<RequestFieldWidget>(field('leave_type')).controller;
    expect(controller.value('org_unit'), isNotEmpty);
    await tapVisible(tester, field('leave_type'));
    final options = find.byWidgetPredicate((widget) =>
        widget is ListTile && widget.onTap != null);
    await waitFor(tester, options.first);
    await tapVisible(tester, options.first);
    expect(controller.value('leave_type'), isNotEmpty);
    for (final name in ['start_date', 'end_date']) {
      await tapVisible(tester, find.descendant(
          of: field(name), matching: find.byTooltip('انتخاب تاریخ شمسی')));
      final today = toPersianDigits(JalaliDate.fromDateTime(DateTime.now()).day);
      await tapVisible(tester, find.descendant(
          of: find.byType(AlertDialog), matching: find.text(today)));
    }
    final reason = 'آزمون ثبت مرخصی ${DateTime.now().microsecondsSinceEpoch}';
    final reasonInput = find.descendant(
        of: field('reason'), matching: find.byType(TextField));
    await tester.ensureVisible(reasonInput);
    await tester.enterText(reasonInput, reason);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tapVisible(tester, find.text('ثبت درخواست'));
    await waitFor(tester, find.text('درخواست شما با موفقیت ثبت شد'));
    final submitted = tester.widget<RequestSubmittedPage>(find.byType(RequestSubmittedPage));
    expect(submitted.pending, isFalse);
    expect(submitted.local, isFalse);
    final number = submitted.request['name'] as String;
    expect(number, isNotEmpty);
    expect((submitted.request['values'] as Map)['reason'], reason);
    await tapVisible(tester, find.text('بازگشت به صفحه اصلی'));
    await tapVisible(tester, find.text('ثبت درخواست'));
    await waitFor(tester, find.text(number));
    expect(find.text(number), findsOneWidget);
    await tester.pageBack();
    await tapVisible(tester, find.text('بیشتر'));
    await tapVisible(tester, find.text('خروج از حساب'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'خروج'));
    await waitFor(tester, find.byKey(const Key('login_button')));
    expect(find.byKey(const Key('username_field')), findsOneWidget);
  }, skip: E2e.skipReason != null, timeout: const Timeout(Duration(minutes: 4)));
}
