import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_issue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('contract dates default to today and require valid end at $width', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HrContractIssuePage(company: 'شرکت', repository: FakeHrContractsRepository(),
            templateRepository: FakeHrContractTemplateRepository()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('پرسنل نمونه ۱ (HR-101)').last);
      await tester.pumpAndSettle();
      final start = find.widgetWithText(TextFormField, 'شروع (شمسی)');
      final end = find.widgetWithText(TextFormField, 'پایان (شمسی)');
      await tester.scrollUntilVisible(end, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<TextFormField>(start).controller!.text,
          toPersianDigits(JalaliDate.fromDateTime(DateTime.now()).format()));
      expect(tester.widget<TextFormField>(end).controller!.text, isEmpty);
      final startValidator = tester.widget<TextFormField>(start).validator!;
      final endValidator = tester.widget<TextFormField>(end).validator!;
      expect(startValidator(''), 'تاریخ شروع الزامی است.');
      expect(startValidator('۱۴۰۵/۱۳/۰۱'), 'تاریخ شروع معتبر نیست.');
      expect(endValidator(''), 'تاریخ پایان الزامی است.');
      expect(endValidator('۱۴۰۵/۰۷/۳۱'), 'تاریخ پایان معتبر نیست.');
      await tester.enterText(start, '۱۴۰۵/۰۸/۱۰');
      expect(endValidator('۱۴۰۵/۰۸/۰۹'), 'تاریخ پایان نباید پیش از تاریخ شروع باشد.');
      expect(endValidator('۱۴۰۵/۰۸/۱۰'), isNull);
      expect(endValidator('۱۴۰۵/۰۸/۱۱'), isNull);
      final save = find.text('ذخیره پیش‌نویس');
      await tester.scrollUntilVisible(save, 400, scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('تاریخ پایان الزامی است.'), -400,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('تاریخ پایان الزامی است.'), findsOneWidget);
      expect(find.byType(HrContractIssuePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
