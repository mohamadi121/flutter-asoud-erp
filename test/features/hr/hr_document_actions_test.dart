import 'package:asoud_erp/core/auth/capabilities.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final role in ['HR User', 'HR Manager', 'System Manager', 'Employee', 'Accounts Manager', 'Payroll Manager']) {
      testWidgets('HR document tiles follow $role permissions at $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: Directionality(textDirection: TextDirection.rtl,
            child: HrDocumentActions(company: 'شرکت', capabilities: Capabilities.fromRoles([role]))),
        ))));
        await tester.pumpAndSettle();
        final operational = ['HR User', 'HR Manager', 'System Manager'].contains(role);
        final designer = ['HR Manager', 'System Manager'].contains(role);
        for (final label in ['قراردادهای پرسنلی', 'گواهی‌های اشتغال به کار', 'احکام استخدام', 'معرفی‌نامه‌های پرسنلی']) {
          expect(find.text(label), operational ? findsOneWidget : findsNothing);
        }
        expect(find.text('قالب‌های قرارداد'), designer ? findsOneWidget : findsNothing);
        expect(find.text('احکام تغییر حقوق و مزایا'), role != 'Employee' && role != 'HR User' ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
