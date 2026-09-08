import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/account_form_cubit.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_of_accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ChartOfAccountsRepository {}

const rows = [
  AccountNode(id: 'g', code: '1', title: 'دارایی‌ها', level: AccountLevel.group),
  AccountNode(id: 'c', code: '11', title: 'دارایی جاری', level: AccountLevel.general, parentId: 'g'),
  AccountNode(id: 'l', code: '1101', title: 'نقد و بانک', level: AccountLevel.ledger, parentId: 'c'),
];

void main() {
  test('changing create level clears parent; edit level cannot change', () async {
    final create = AccountFormCubit(initialLevel: AccountLevel.ledger, initialParentId: 'c');
    create.setLevel(AccountLevel.general);
    expect(create.state.parentId, isNull);
    final edit = AccountFormCubit(account: rows.last);
    edit.setLevel(AccountLevel.group);
    expect(edit.state.level, AccountLevel.ledger);
    await create.close();
    await edit.close();
  });

  testWidgets('tree accordion menu and child form preserve level and parent', (tester) async {
    final repo = _Repository();
    when(() => repo.getAccounts('office')).thenAnswer((_) async => rows);
    await tester.pumpWidget(MaterialApp(home: ChartOfAccountsPage(company: 'office', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('نقد و بانک'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byKey(const ValueKey('account-tree-card')), findsOneWidget);
    await tester.tap(find.text('دارایی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('نقد و بانک'), findsNothing);
    await tester.tap(find.text('دارایی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('نقد و بانک'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('افزودن زیرمجموعه'));
    await tester.pumpAndSettle();
    expect(find.text('سرفصل حساب کل'), findsWidgets);
    expect(find.text('گروه حساب والد *'), findsOneWidget);
    expect(find.text('نوع حساب *'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
