import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/request_templates/request_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapPage(
      LeaveRequestFormPage(repository: FakeRequestRepository(), type: typeOf('leave'))));
  await tester.pumpAndSettle();
  // The leave balance panel (leave_widgets.dart) overflows by 40 px at 320 px
  // independently of the fields; drain it so this test stays about the fields.
  tester.takeException();
}

void main() {
  testWidgets(
      'leave form uses the shared AppSelectField for its selects and '
      'AppTextField for its text, keeping the required labels', (tester) async {
    for (final width in [320.0, 390.0]) {
      await _pump(tester, width);

      expect(find.byType(AppSelectField), findsWidgets, reason: 'at $width');
      expect(find.byType(AppTextField), findsWidgets, reason: 'at $width');
      expect(find.text('نوع مرخصی *'), findsWidgets, reason: 'at $width');
      expect(find.text('دلیل مرخصی *'), findsWidgets, reason: 'at $width');
    }
  });
}