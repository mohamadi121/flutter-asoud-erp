import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/account_form_cubit.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_of_accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/account_form_page.dart';
import 'package:asoud_erp/features/accounting/presentation/cubit/chart_of_accounts_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ChartOfAccountsRepository {}

const rows = [
  AccountNode(
      id: 'g', code: '1', title: 'دارایی‌ها', level: AccountLevel.group),
  AccountNode(
      id: 'c',
      code: '11',
      title: 'دارایی جاری',
      level: AccountLevel.general,
      parentId: 'g'),
  AccountNode(
      id: 'l',
      code: '1101',
      title: 'نقد و بانک',
      level: AccountLevel.ledger,
      parentId: 'c'),
];

void main() {
  setUpAll(() => registerFallbackValue(rows.first));
  test('numeric code sorting supports Persian and Arabic digits', () {
    final codes = ['10', '۲', '١', '11'];
    codes.sort(compareAccountCodes);
    expect(codes, ['١', '۲', '10', '11']);
  });
  test('contextual form prevents changing its parent and level', () async {
    final cubit = AccountFormCubit(
        initialLevel: AccountLevel.general,
        initialParentId: 'g',
        lockHierarchy: true);
    cubit.setLevel(AccountLevel.ledger);
    cubit.setParent('other');
    expect(cubit.state.level, AccountLevel.general);
    expect(cubit.state.parentId, 'g');
    await cubit.close();
  });

  testWidgets(
      'staged navigation shows siblings only and refreshes after creating a child',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repository();
    final accounts = [...rows];
    when(() => repo.getAccounts('office'))
        .thenAnswer((_) async => accounts.toList());
    when(() => repo.createAccount('office', any(),
        autoCode: any(named: 'autoCode'))).thenAnswer((call) async {
      final value = call.positionalArguments[1] as AccountNode;
      expect(value.parentId, 'g');
      expect(value.level, AccountLevel.general);
      final saved = AccountNode(
          id: 'c2',
          code: '12',
          title: value.title,
          level: value.level,
          parentId: value.parentId,
          detailGroupIds: value.detailGroupIds);
      accounts.add(saved);
      return saved;
    });
    await tester.pumpWidget(MaterialApp(
        home: ChartOfAccountsPage(company: 'office', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    final menu = tester.getCenter(find.byKey(const ValueKey('account-menu-g')));
    final code = tester.getCenter(find.text('1'));
    expect(menu.dx, lessThan(code.dx));
    expect(tester.widget<Text>(find.text('1')).style!.fontSize, 16);
    await tester.tap(find.text('نمای مرحله‌ای'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-g')), findsOneWidget);
    expect(find.text('دارایی جاری'), findsNothing);
    expect(find.text('نقد و بانک'), findsNothing);
    await tester.tap(find.text('دارایی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('دارایی جاری'), findsOneWidget);
    expect(find.text('نقد و بانک'), findsNothing);
    await tester.tap(find.text('دارایی جاری'));
    await tester.pumpAndSettle();
    expect(find.text('نقد و بانک'), findsOneWidget);
    expect(find.text('افزودن حساب معین'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stage-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('افزودن حساب کل'));
    await tester.pumpAndSettle();
    expect(find.text('گروه حساب والد *'), findsNothing);
    expect(find.text('نمای مرحله‌ای'), findsNothing);
    final cubit =
        tester.element(find.text('نام حساب *')).read<AccountFormCubit>();
    expect(cubit.state.parentId, 'g');
    await tester.enterText(find.byType(TextFormField).first, 'کل جدید');
    await tester.tap(find.text('ذخیره حساب'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFormPage), findsNothing);
    expect(find.text('کل جدید'), findsOneWidget);
    expect(find.text('دارایی جاری'), findsOneWidget);
    await tester.tap(find.text('نمای درختی'));
    await tester.pumpAndSettle();
    expect(find.text('کل جدید'), findsOneWidget);
    expect(find.text('نقد و بانک'), findsOneWidget);
    await tester.tap(find.text('نمای مرحله‌ای'));
    await tester.pumpAndSettle();
    expect(find.text('کل جدید'), findsOneWidget);
    expect(find.text('نقد و بانک'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('changing create level clears parent; edit level cannot change',
      () async {
    final create = AccountFormCubit(
        initialLevel: AccountLevel.ledger, initialParentId: 'c');
    create.setLevel(AccountLevel.general);
    expect(create.state.parentId, isNull);
    final edit = AccountFormCubit(account: rows.last);
    edit.setLevel(AccountLevel.group);
    expect(edit.state.level, AccountLevel.ledger);
    await create.close();
    await edit.close();
  });

  testWidgets('tree accordion menu and child form preserve level and parent',
      (tester) async {
    final repo = _Repository();
    when(() => repo.getAccounts('office')).thenAnswer((_) async => rows);
    await tester.pumpWidget(MaterialApp(
        home: ChartOfAccountsPage(company: 'office', repository: repo)));
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
    expect(find.text('گروه حساب والد *'), findsNothing);
    expect(find.text('سطح حساب *'), findsNothing);
    expect(find.text('نوع حساب *'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
