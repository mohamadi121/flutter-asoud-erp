import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/account_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/account_form_page.dart';

class _Repository extends Mock implements ChartOfAccountsRepository {}
class _Groups extends Mock implements DetailGroupRepository {}

void main() {
  testWidgets('edit form restores checked groups and supports multiple choices', (tester) async {
    final repo = _Repository();
    final groups = _Groups();
    when(() => repo.getAccounts('office')).thenAnswer((_) async => []);
    when(() => groups.getGroups()).thenAnswer((_) async => const [
      DetailGroup(id: '10000', code: '10000', title: 'مشتریان'),
      DetailGroup(id: '30000', code: '30000', title: 'پرسنل'),
    ]);
    await tester.pumpWidget(RepositoryProvider<DetailGroupRepository>.value(
      value: groups,
      child: MaterialApp(home: AccountFormPage(company: 'office', repository: repo,
        account: const AccountNode(id: 'g', code: '1', title: 'حساب',
          level: AccountLevel.group, detailGroupIds: ['10000']))),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('گروه‌های تفصیلی شناور'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('پرسنل'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'مشتریان')).value, isTrue);
    await tester.tap(find.text('پرسنل'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'پرسنل')).value, isTrue);
    expect(tester.takeException(), isNull);
  });
  setUpAll(() => registerFallbackValue(const AccountNode(id: '', code: '', title: '', level: AccountLevel.group)));
  for (final level in [AccountLevel.group, AccountLevel.general, AccountLevel.ledger]) {
    test('multiple groups restored and saved at $level', () async {
      final repo = _Repository();
      final account = AccountNode(id: 'a', code: '11', title: 'حساب', level: level,
          parentId: 'parent', detailGroupIds: const ['10000', '30000']);
      when(() => repo.getAccounts('office')).thenAnswer((_) async => [account]);
      when(() => repo.updateAccount('office', any())).thenAnswer((call) async => call.positionalArguments[1] as AccountNode);
      final cubit = AccountFormCubit(account: account, company: 'office', repository: repo);
      expect(cubit.state.detailGroupIds, ['10000', '30000']);
      cubit.selectDetailGroup('10000', false);
      cubit.selectDetailGroup('20000', true);
      await cubit.submit();
      expect(cubit.state.status, AccountFormStatus.success);
      expect(cubit.state.savedAccount!.detailGroupIds, ['30000', '20000']);
      expect(cubit.state.savedAccount!.level, level);
      await cubit.close();
    });
  }
  test('parent with children cannot become terminal', () async {
    final repo = _Repository();
    const parent = AccountNode(id: 'g', code: '1', title: 'دارایی', level: AccountLevel.group);
    when(() => repo.getAccounts('office')).thenAnswer((_) async => [parent,
      const AccountNode(id: 'c', code: '11', title: 'کل', level: AccountLevel.general, parentId: 'g')]);
    final cubit = AccountFormCubit(account: parent, company: 'office', repository: repo);
    cubit.selectDetailGroup('10000', true);
    await cubit.submit();
    expect(cubit.state.status, AccountFormStatus.failure);
    verifyNever(() => repo.updateAccount(any(), any()));
    await cubit.close();
  });
}
