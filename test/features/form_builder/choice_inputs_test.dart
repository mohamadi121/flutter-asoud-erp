import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_runtime/field_inputs/choice_inputs.dart';

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('choice ids save while Persian labels and deleted choices display at $width', (tester) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Form(
              child: Builder(
                builder: (context) => Column(
                  children: [
                    buildChoiceInput(
                    context: context,
                    f: {
                      'key': 'state',
                      'type': 'Select',
                      'options': [
                        {'id': 'approved', 'label': 'تأییدشده'},
                      ],
                    },
                    value: 'approved',
                    label: 'وضعیت',
                    required: false,
                    onChanged: (value) => changed = '$value',
                  )!,
                    buildChoiceInput(
                    context: context,
                    f: {'key': 'old', 'type': 'Select', 'options': const []},
                    value: 'removed_option',
                    label: 'گزینه قدیمی',
                    required: false,
                    onChanged: (_) {},
                  )!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('تأییدشده'), findsOneWidget);
    expect(find.text('گزینهٔ حذف‌شده'), findsOneWidget);
    await tester.tap(find.text('تأییدشده'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأییدشده').last);
    expect(changed, 'approved');
    });
  }
}
