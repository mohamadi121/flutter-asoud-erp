import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_template_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ChartOfAccountsRepository {}

void main() {
  for (final existing in [false, true]) {
    testWidgets('template apply allowed only for empty chart: $existing',
        (tester) async {
      final repository = _Repository();
      when(() => repository.previewTemplate('office', 'Iran Standard'))
          .thenAnswer((_) async => const [
                ChartTemplateRow(key: '1', level: 'Group', title: 'دارایی‌ها'),
              ]);
      when(() => repository.getAccounts('office')).thenAnswer((_) async => [
            if (existing)
              const AccountNode(
                id: 'manual', code: '9', title: 'دستی',
                level: AccountLevel.group,
              ),
          ]);
      await tester.pumpWidget(MaterialApp(
        home: ChartTemplatePage(company: 'office', repository: repository),
      ));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton, 'ایجاد سرفصل‌های پیشنهادی',
      ));
      expect(button.onPressed == null, existing);
      expect(find.text('این دفتر سرفصل ثبت‌شده دارد'),
          existing ? findsOneWidget : findsNothing);
      verifyNever(() => repository.applyTemplate(any(), any()));
    });
  }
}
