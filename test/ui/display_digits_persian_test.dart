import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_of_accounts_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'درخت سرفصل‌ها کد حساب را با ارقام فارسی نمایش می‌دهد (نه لاتین)',
      (tester) async {
    const group = AccountNode(
        id: 'g1', code: '1', title: 'دارایی‌ها', level: AccountLevel.group);
    const general = AccountNode(
        id: 'g11',
        code: '11',
        title: 'دارایی‌های جاری',
        level: AccountLevel.general,
        parentId: 'g1');
    const detail = AccountNode(
        id: 'g1101',
        code: '1101',
        title: 'موجودی نقد و بانک',
        level: AccountLevel.detail,
        parentId: 'g11');
    await pump(
        tester,
        ChartOfAccountsPage(
            company: 'شرکت نمونه',
            repository:
                _FakeChartRepository(accounts: [group, general, detail])));
    expect(find.text('۱۱۰۱'), findsOneWidget);
    expect(find.text('۱۱'), findsOneWidget);
    expect(find.text('1101'), findsNothing);
    expect(find.text('11'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('گروه‌های تفصیلی کد را با ارقام فارسی و ذخیره‌شده را لاتین نشان می‌دهد',
      (tester) async {
    await pump(
        tester,
        const _DetailGroupsHost(),
        size: const Size(390, 1200),
    );
    expect(find.text('۱۰۰۰۰'), findsOneWidget);
    expect(find.text('10000'), findsNothing);
    await tester.tap(find.text('مشتریان'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, '10000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('پرونده شخص شماره تلفن را با ارقام فارسی نمایش می‌دهد', (tester) async {
    const profile = PartyProfile(
      kind: PartyKind.individual,
      displayName: 'حمید روشنی',
      roles: {PartyRole.customer},
      mobile: '09120000010',
      phone: '02188990011',
    );
    await pump(
        tester,
        PartyDetailsPage(profile: profile),
        size: const Size(390, 2000));
    await tester.ensureVisible(find.text('راه‌های ارتباطی'));
    await tester.tap(find.text('راه‌های ارتباطی'));
    await tester.pumpAndSettle();
    expect(find.text('۰۹۱۲۰۰۰۰۰۱۰'), findsOneWidget);
    expect(find.text('۰۲۱۸۸۹۹۰۰۱۱'), findsOneWidget);
    expect(find.text('09120000010'), findsNothing);
    expect(profile.mobile, '09120000010');
    expect(tester.takeException(), isNull);
  });
}

class _DetailGroupsHost extends StatelessWidget {
  const _DetailGroupsHost();
  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DetailGroupRepository>.value(
              value: _FakeDetailGroupRepository()),
        ],
        child: const DetailGroupsPage(),
      );
}

class _FakeChartRepository implements ChartOfAccountsRepository {
  _FakeChartRepository({this.accounts = const []});
  final List<AccountNode> accounts;
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
  Future<List<AccountNode>> getAccounts(String company) async => accounts;
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