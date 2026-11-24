import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/office_input_validation.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_office_repository.dart';

void main() {
  test('contact length, prefixes and identity checksums remain enforced', () {
    expect(OfficeInputValidation.mobile('۰۹۱۲۳۴۵۶۷۸۹'), isNull);
    expect(OfficeInputValidation.mobile('091234567890'), isNotNull);
    expect(OfficeInputValidation.mobile('02112345678'), isNotNull);
    expect(OfficeInputValidation.landline('۰۲۱۱۲۳۴۵۶۷۸'), isNull);
    expect(OfficeInputValidation.landline('21123456789'), isNotNull);
    expect(OfficeInputValidation.landline('021123456789'), isNotNull);
    expect(OfficeInputValidation.nationalId('1111111111', legal: false), isNotNull);
    expect(OfficeInputValidation.nationalId('11111111111', legal: true), isNotNull);
  });

  for (final type in OfficeType.values) {
    testWidgets('office $type input rejects extra digits and letters', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepositoryProvider<OfficeRepository>.value(
        value: FakeOfficeRepository(),
        child: MaterialApp(theme: AsoudTheme.light,
          home: Directionality(textDirection: TextDirection.rtl,
            child: OfficeFormPage(officeType: type))),
      ));
      await tester.pumpAndSettle();
      for (final item in {'nationalId': type == OfficeType.legal ? 11 : 10,
                         'phone': 11, 'landline': 11}.entries) {
        final field = find.byKey(ValueKey('office-${item.key}-0'));
        await tester.ensureVisible(field);
        await tester.enterText(field, '۰۱۲۳۴۵۶۷۸۹012abc');
        await tester.pumpAndSettle();
        final input = tester.widget<EditableText>(find.descendant(
            of: field, matching: find.byType(EditableText)));
        expect(input.controller.text.length, item.value);
        expect(input.controller.text, isNot(contains('abc')));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
