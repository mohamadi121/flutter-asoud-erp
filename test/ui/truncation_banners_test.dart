import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/chart_setup_page.dart';
import 'package:asoud_erp/features/accounting/presentation/pages/detail_groups_page.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/roles/presentation/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/roles/user_access_fakes.dart';

const _chartHint =
    'برای دیدن ساختار واقعی قالب، «استفاده از قالب آماده» را انتخاب کنید. تا قبل از تأیید شما هیچ حسابی در ASOUD ERP ایجاد نمی‌شود.';
const _detailGroupsHelp =
    'یک کد تفصیلی می‌تواند به چند حساب معین متصل شود؛ مانند مشتری، بانک، پروژه یا مرکز هزینه.';
const _userAccessGuidance =
    'برای ویرایش اطلاعات کاربر، کارت او را نگه دارید. فهرست تا ۱۰۰ نتیجه دارد؛ برای محدودکردن نتایج جستجو کنید.';

void _expectWrappingText(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  final widget = tester.widget<Text>(finder);
  expect(widget.maxLines, isNull);
  expect(widget.overflow, isNull);
  expect(widget.softWrap, isTrue);
  expect(tester.getSize(finder).height, greaterThan(16));
}

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
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

void main() {
  test(
      'formatUserGreetingRoles caps long role lists at three titles plus a Persian «+N»',
      () {
    final roles = [
      'Administrator',
      'Academics User',
      'Agriculture User',
      'Dashboard Manager',
      'Delivery Manager',
    ];
    final greeting = formatUserGreetingRoles(roles);

    expect(greeting, startsWith('مدیر سامانه، کاربر آموزش، کارشناس کشاورزی'));
    expect(greeting, contains('+۲'));
    expect(greeting, isNot(contains('مدیر داشبورد')));
    expect(greeting, isNot(contains('مدیر تحویل')));

    expect(formatUserGreetingRoles(const []), 'کاربر سامانه');
    expect(
        formatUserGreetingRoles(const ['Administrator', 'Academics User']),
        'مدیر سامانه، کاربر آموزش');
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('chart setup preview hint wraps fully at ${width}px',
        (tester) async {
      await _pump(tester, const ChartSetupPage(company: 'شرکت نمونه آسود'),
          Size(width, 1200));
      _expectWrappingText(tester, _chartHint);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detail groups help text wraps fully at 320px', (tester) async {
    await _pump(tester, const _DetailGroupsHost(), const Size(320, 1200));
    _expectWrappingText(tester, _detailGroupsHelp);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user access guidance wraps fully at 320px', (tester) async {
    await _pump(
      tester,
      UserAccessPage(
          role: userAccessRole, repository: UserAccessRepository(UserAccessClient())),
      const Size(320, 1200),
    );
    _expectWrappingText(tester, _userAccessGuidance);
    expect(tester.takeException(), isNull);
  });
}

class _DetailGroupsHost extends StatelessWidget {
  const _DetailGroupsHost();
  @override
  Widget build(BuildContext context) => RepositoryProvider<DetailGroupRepository>.value(
        value: _FakeDetailGroupRepository(),
        child: const DetailGroupsPage(),
      );
}

class _FakeDetailGroupRepository implements DetailGroupRepository {
  static const groups = [DetailGroup(id: '10000', code: '10000', title: 'مشتریان')];
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
