import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/domain/entities/account_node.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/chart_of_accounts_repository.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_setup_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
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

  testWidgets('گروه‌های تفصیلی از repository نمایش داده می‌شوند',
      (tester) async {
    await pumpPage(tester, const DetailGroupsPage());
    expect(find.text('گروه تفصیلی شناور'), findsOneWidget);
    expect(find.text('مشتریان'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeChartRepository implements ChartOfAccountsRepository {
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
  Future<DetailGroup> saveGroup(
          {required String code, required String title}) async =>
      DetailGroup(id: code, code: code, title: title);
}
