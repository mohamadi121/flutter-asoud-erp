import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_office_repository.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepositoryProvider<OfficeRepository>.value(
    value: FakeOfficeRepository(),
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: const OfficeFormPage(officeType: OfficeType.personal),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'office form renders the shared AppTextField and AppSelectField at 320 '
      'and 390 px RTL', (tester) async {
    for (final width in [320.0, 390.0]) {
      await _pump(tester, width);

      expect(find.byType(AppTextField), findsWidgets, reason: 'at $width');
      expect(find.byType(AppSelectField), findsWidgets, reason: 'at $width');
      expect(tester.takeException(), isNull);
    }
  });
}