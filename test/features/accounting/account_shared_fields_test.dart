import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/account_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester,
      _FakeChartRepository chart, _FakeDetailGroupRepository groups) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ChartOfAccountsRepository>.value(value: chart),
        RepositoryProvider<DetailGroupRepository>.value(value: groups),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AccountFormPage(
                        company: 'شرکت نمونه', repository: chart))),
                child: const Text('باز کردن فرم حساب'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('باز کردن فرم حساب'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'فرم حساب با فیلدهای مشترک، انتخاب والد/ماهیت/نوع و ذخیرهٔ درست را پشتیبانی می‌کند',
      (tester) async {
    final chart = _FakeChartRepository();
    await pumpPage(tester, chart, _FakeDetailGroupRepository());
    expect(find.text('نام حساب *'), findsOneWidget);
    expect(find.byType(AppSelectField), findsOneWidget);

    await tester.tap(find.text('معین'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSelectField), findsNWidgets(3));
    expect(find.text('حساب کل والد *'), findsOneWidget);
    expect(find.text('ماهیت حساب *'), findsOneWidget);
    expect(find.text('نوع حساب *'), findsOneWidget);

    await tester.tap(find.text('انتخاب حساب کل'));
    await tester.pumpAndSettle();
    expect(find.text('۱۱  دارایی‌های جاری'), findsWidgets);
    await tester.tap(find.text('۱۱  دارایی‌های جاری'));
    await tester.pumpAndSettle();
    expect(find.text('۱۱  دارایی‌های جاری'), findsOneWidget);

    await tester.tap(find.text('بدهکار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بستانکار'));
    await tester.pumpAndSettle();
    expect(find.text('بستانکار'), findsOneWidget);

    await tester.tap(find.text('نوع حساب را انتخاب کنید'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بانک'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'نام حساب *'), 'صندوق شعبه مرکزی');
    await tester.tap(find.text('ذخیره حساب'));
    await tester.pumpAndSettle();

    expect(chart.created, hasLength(1));
    final saved = chart.created.single;
    expect(saved.level, AccountLevel.ledger);
    expect(saved.parentId, 'assets-current');
    expect(saved.nature, AccountNature.credit);
    expect(saved.accountType, 'Bank');
    expect(saved.title, 'صندوق شعبه مرکزی');
    expect(tester.takeException(), isNull);
  });
}

class _FakeChartRepository implements ChartOfAccountsRepository {
  final created = <AccountNode>[];
  @override
  Future<void> deleteAccount(String company, AccountNode account) async {}
  @override
  Future<List<ChartTemplateRow>> previewTemplate(
          String company, String template) async =>
      const [];
  @override
  Future<List<AccountNode>> applyTemplate(
          String company, String template) async =>
      const [];
  @override
  Future<List<AccountNode>> importAccounts(
          String company, List<Map<String, dynamic>> rows) async =>
      const [];
  @override
  Future<List<AccountNode>> getAccounts(String company) async => const [
        AccountNode(
            id: 'assets',
            code: '1',
            title: 'دارایی‌ها',
            level: AccountLevel.group),
        AccountNode(
            id: 'assets-current',
            code: '11',
            title: 'دارایی‌های جاری',
            level: AccountLevel.general,
            parentId: 'assets'),
      ];
  @override
  Future<AccountNode> createAccount(String company, AccountNode account,
          {required bool autoCode}) async {
    created.add(account);
    return account;
  }

  @override
  Future<AccountNode> updateAccount(
          String company, AccountNode account) async =>
      account;
}

class _FakeDetailGroupRepository implements DetailGroupRepository {
  @override
  Future<List<DetailGroup>> getGroups() async => const [];
  @override
  Future<List<DetailGroup>> seedDefaults() async => const [];
  @override
  Future<void> disableGroup(String id) async {}
  @override
  Future<DetailGroup> saveGroup(
          {required String code, required String title, String? id}) async =>
      DetailGroup(id: code, code: code, title: title);
}