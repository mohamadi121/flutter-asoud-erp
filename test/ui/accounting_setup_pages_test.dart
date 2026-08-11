import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_setup_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_excel_import_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_template_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/account_level_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ChartOfAccountsRepository>.value(
            value: _FakeChartRepository()),
        RepositoryProvider<DetailGroupRepository>.value(
            value: _FakeDetailGroupRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('صفحه انتخاب سرفصل‌ها در عرض 390 بدون overflow است',
      (tester) async {
    await pumpPage(tester, const ChartSetupPage(company: 'شرکت نمونه'));
    expect(find.text('سرفصل‌های حسابداری'), findsOneWidget);
    expect(find.text('ایجاد دستی'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('قالب پیشنهادی و ورود اکسل از صفحه سرفصل‌ها باز می‌شوند',
      (tester) async {
    await pumpPage(tester, const ChartSetupPage(company: 'شرکت نمونه'));
    await tester.tap(find.text('استفاده از قالب آماده'));
    await tester.pumpAndSettle();
    expect(find.byType(ChartTemplatePage), findsOneWidget);
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ورود از اکسل'));
    await tester.pumpAndSettle();
    expect(find.byType(ChartExcelImportPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('گروه‌های تفصیلی از repository نمایش داده می‌شوند',
      (tester) async {
    await pumpPage(tester, const DetailGroupsPage());
    expect(find.text('گروه تفصیلی شناور'), findsOneWidget);
    expect(find.text('مشتریان'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('گروه تفصیلی پیش‌فرض قابل ویرایش است', (tester) async {
    await pumpPage(tester, const DetailGroupsPage());
    await tester.tap(find.text('مشتریان'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش گروه تفصیلی'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'مشتریان'), findsOneWidget);
    expect(find.widgetWithText(TextField, '10000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('صفحه کل و معین با کنترل نمای سفارشی نمایش داده می‌شود',
      (tester) async {
    const general = AccountNode(
      id: 'assets-current',
      code: '11',
      title: 'دارایی‌های جاری',
      level: AccountLevel.general,
      parentId: 'assets',
    );
    const group = AccountNode(
      id: 'assets',
      code: '1',
      title: 'دارایی‌ها',
      level: AccountLevel.group,
      children: [general],
    );
    await pumpPage(
        tester,
        AccountLevelPage(
          parent: group,
          company: 'شرکت نمونه',
          repository: _FakeChartRepository(),
        ));
    expect(find.text('سرفصل کل'), findsOneWidget);
    expect(find.text('نمای مرحله‌ای'), findsOneWidget);
    expect(find.text('نمای درختی'), findsOneWidget);
    expect(find.text('دارایی‌های جاری'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AccountLevelPage),
      matchesGoldenFile('goldens/account_level_390.png'),
    );
  }, tags: 'golden');
}

class _FakeChartRepository implements ChartOfAccountsRepository {
  @override
  Future<List<ChartTemplateRow>> previewTemplate(
          String company, String template) async =>
      const [
        ChartTemplateRow(key: '1', level: 'Group', title: 'دارایی‌ها'),
        ChartTemplateRow(
            key: '11',
            level: 'General',
            title: 'دارایی‌های جاری',
            parentKey: '1'),
      ];

  @override
  Future<List<AccountNode>> applyTemplate(
          String company, String template) async =>
      const [];
  @override
  Future<List<AccountNode>> importAccounts(
          String company, List<Map<String, dynamic>> rows) async =>
      const [];
  @override
  Future<List<AccountNode>> getAccounts(String company) async => const [];
  @override
  Future<AccountNode> createAccount(String company, AccountNode account,
          {required bool autoCode}) async =>
      account;
  @override
  Future<AccountNode> updateAccount(
          String company, AccountNode account) async =>
      account;
}

class _FakeDetailGroupRepository implements DetailGroupRepository {
  static const groups = [
    DetailGroup(id: '10000', code: '10000', title: 'مشتریان'),
    DetailGroup(id: '20000', code: '20000', title: 'تأمین‌کنندگان'),
  ];
  @override
  Future<List<DetailGroup>> getGroups() async => groups;
  @override
  Future<List<DetailGroup>> seedDefaults() async => groups;
  @override
  Future<void> disableGroup(String id) async {}
  @override
  Future<DetailGroup> saveGroup(
          {required String code, required String title, String? id}) async =>
      DetailGroup(id: code, code: code, title: title);
}
