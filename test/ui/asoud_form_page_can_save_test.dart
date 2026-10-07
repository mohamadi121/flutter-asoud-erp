import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int> pump(WidgetTester tester, {bool? canSave}) async {
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: AsoudFormPage(
          title: 'فرم',
          formKey: GlobalKey<FormState>(),
          onSave: () => saved++,
          saveLabel: 'ثبت درخواست',
          canSave: canSave ?? true,
          children: const [Text('محتوا')],
        )));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('the primary button is enabled by default', (tester) async {
    await pump(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('canSave: false disables the primary button only',
      (tester) async {
    await pump(tester, canSave: false);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('ثبت درخواست'), findsOneWidget, reason: 'label kept');
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
        reason: 'انصراف still works');
  });
}
