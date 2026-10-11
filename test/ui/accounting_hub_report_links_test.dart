import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/accounting_home_page.dart';
import 'package:asoud_erp/features/reports/presentation/pages/ledger_page.dart';
import 'package:asoud_erp/features/reports/presentation/pages/trial_balance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl,
        child: const AccountingHomePage(company: 'شرکت نمونه آسود')));

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('«دفتر کل» opens the ledger page at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('دفتر کل'));
      await tester.pumpAndSettle();

      expect(find.byType(LedgerPage), findsOneWidget);
      expect(find.text('حساب *'), findsOneWidget);
      expect(find.text('نمایش گزارش'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«تراز آزمایشی» opens the trial balance page at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('تراز آزمایشی'));
      await tester.pumpAndSettle();

      expect(find.byType(TrialBalancePage), findsOneWidget);
      expect(find.text('حساب (اختیاری)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the remaining report rows stay dimmed at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('به‌زودی'), findsNWidgets(3));
      await tester.tap(find.text('سند حسابداری'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountingHomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}