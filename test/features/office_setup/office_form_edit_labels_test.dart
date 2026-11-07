import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_office_repository.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final editing in [true, false]) {
      testWidgets('office form editing=$editing at $width px RTL',
          (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(RepositoryProvider<OfficeRepository>.value(
          value: FakeOfficeRepository(),
          child: MaterialApp(
            theme: AsoudTheme.light,
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
            home: OfficeFormPage(
              officeType: OfficeType.personal,
              office: editing
                  ? Office(
                      name: 'دفتر موجود',
                      type: OfficeType.personal,
                      fiscalYearStart: DateTime.now(),
                    )
                  : null,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text(editing ? 'ویرایش دفتر کار' : 'ایجاد دفتر کار'),
            editing ? findsOneWidget : findsNWidgets(2));
        expect(
            find.text(editing
                ? 'ویرایش اطلاعات ثبت‌شدهٔ دفتر'
                : 'تعریف یک دفتر کاری جدید'),
            findsOneWidget);
        expect(find.text('ذخیرهٔ تغییرات'),
            editing ? findsOneWidget : findsNothing);
        expect(find.text('پیشنهاد اطلاعات نمونه'),
            editing ? findsNothing : findsOneWidget);
        if (editing) expect(find.text('ایجاد دفتر کار'), findsNothing);
        expect(tester.takeException(), isNull);

        // Root cancellation also uses edit wording and never says a new office
        // will be created. Creating retains its existing confirmation copy.
        await tester.tap(find.text('انصراف'));
        await tester.pumpAndSettle();
        expect(
            find.text(
                editing ? 'انصراف از ویرایش دفتر؟' : 'انصراف از ایجاد دفتر؟'),
            findsOneWidget);
        if (editing) {
          expect(find.textContaining('دفتر ایجاد نمی‌شود'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
