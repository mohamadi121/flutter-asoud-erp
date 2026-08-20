import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_form_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_detail_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_management_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_links_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/personnel_roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('کدهای تفصیلی از منوی صفحه مشخصات باز می‌شوند', (tester) async {
    await tester.pumpWidget(_app(const PartyDetailPage(
      profile: PartyProfile(
        id: 'ASOUD-PARTY-1',
        kind: PartyKind.individual,
        displayName: 'مشتری نمونه',
        roles: {PartyRole.customer},
        detailGroups: {'10000'},
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('کدهای تفصیلی'));
    await tester.pumpAndSettle();
    expect(find.text('تفصیلی‌های مشتری'), findsOneWidget);
    expect(find.text('افزودن کد جدید'), findsOneWidget);
  });

  testWidgets('صفحه تفصیلی‌های شخص عملیات اتصال و ایجاد را نمایش می‌دهد',
      (tester) async {
    final repository = _FakePartyRepository();
    await tester.pumpWidget(_app(PartyLinksPage(
      repository: repository,
      profile: const PartyProfile(
        id: 'ASOUD-PARTY-1',
        kind: PartyKind.individual,
        displayName: 'تأمین‌کننده نمونه',
        roles: {PartyRole.supplier},
        detailGroups: {'20000'},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('تفصیلی‌های تأمین‌کننده'), findsOneWidget);
    expect(find.text('اتصال کد موجود'), findsOneWidget);
    expect(find.text('افزودن کد جدید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('صفحه تنظیم ترکیب نقش‌های پرسنلی بدون overflow است',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const PersonnelRolesPage()));
    await tester.pumpAndSettle();
    expect(find.text('تنظیمات نقش‌های پرسنلی'), findsOneWidget);
    expect(find.text('حالت پایه'), findsOneWidget);
    expect(find.text('تأیید ترکیب نقش‌ها'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('صفحه مشخصات مشتری در عرض $width بدون overflow است',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const PartyDetailPage(
        profile: PartyProfile(
          id: 'ASOUD-PARTY-00001',
          kind: PartyKind.individual,
          displayName: 'احمد سماوات',
          roles: {PartyRole.customer, PartyRole.supplier},
          mobile: '09121234567',
          email: 'ahmad@example.com',
          province: 'تهران',
          city: 'تهران',
          address: 'خیابان نمونه',
          creditLimit: 25000000,
          floatingDetails: [
            FloatingDetail(
              id: '10001',
              code: '10001',
              title: 'احمد سماوات',
              type: 'Customer',
              groupId: '10000',
              groupTitle: 'مشتریان',
            ),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('مشخصات مشتری'), findsOneWidget);
      expect(find.textContaining('10001'), findsOneWidget);
      expect(find.text('تماس'), findsOneWidget);
      expect(find.text('پیامک'), findsOneWidget);
      expect(find.text('ویرایش اطلاعات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('صفحه مدیریت اشخاص مطابق جریان مرجع نمایش داده می‌شود',
      (tester) async {
    await tester.pumpWidget(_app(const PartyManagementPage()));
    await tester.pumpAndSettle();
    expect(find.text('مدیریت اشخاص'), findsOneWidget);
    expect(find.text('همه'), findsOneWidget);
    expect(find.text('مشتریان'), findsOneWidget);
    expect(find.text('تأمین‌کنندگان'), findsOneWidget);
    expect(find.text('پرسنل'), findsOneWidget);
    expect(find.text('شخص جدید'), findsOneWidget);
    expect(find.text('بازاریاب'), findsNothing);
    await tester.tap(find.text('شخص جدید'));
    await tester.pumpAndSettle();
    expect(find.text('حقیقی'), findsOneWidget);
    expect(find.text('حقوقی'), findsOneWidget);
    await tester.tap(find.text('پرسنل'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('بازاریاب'), findsOneWidget);
    expect(find.text('فروشنده'), findsOneWidget);
    expect(find.text('صندوق'), findsOneWidget);
    expect(find.text('تنخواه‌گردان'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('اطلاعات اصلی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('فرم تأمین‌کننده در عرض $width بدون overflow است',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const PartyFormPage(
        company: 'شرکت نمونه',
        initialRole: PartyRole.supplier,
      )));
      await tester.pumpAndSettle();
      expect(find.text('ایجاد تأمین‌کننده'), findsWidgets);
      expect(find.byIcon(Icons.tag_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('فرم پرسنل نقش و اطلاعات شغلی را نمایش می‌دهد', (tester) async {
    await tester.pumpWidget(_app(const PartyFormPage(
      company: 'شرکت نمونه',
      initialRole: PartyRole.employee,
    )));
    await tester.pumpAndSettle();
    expect(find.text('ایجاد پرسنل'), findsWidgets);
    await tester.scrollUntilVisible(find.text('اطلاعات شغلی و بانکی'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('اطلاعات شغلی و بانکی'), findsOneWidget);
  });
}

Widget _app(Widget home) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PartyRepository>.value(
            value: _FakePartyRepository()),
        RepositoryProvider<DetailGroupRepository>.value(
            value: _FakeDetailGroupRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        theme: AsoudTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    );

class _FakePartyRepository implements PartyRepository {
  @override
  Future<FloatingDetail> createDetail({
    required String title,
    required String type,
    required String detailGroup,
    required String profileId,
  }) async =>
      FloatingDetail(
          id: '1',
          code: '${detailGroup}00001',
          title: title,
          type: type,
          groupId: detailGroup);

  @override
  Future<void> linkDetail(
      {required String detailId, required String profileId}) async {}

  @override
  Future<void> disableParty(String id) async {}

  @override
  Future<List<PartyProfile>> list(
          {String? company, PartyRole? role, String? search}) async =>
      const [];
  @override
  Future<List<FloatingDetail>> listDetails(
          {String? detailGroup, String? search}) async =>
      const [];
  @override
  Future<String> previewNextCode(String detailGroup) async =>
      '${detailGroup}00001';
  @override
  Future<PartyProfile> save(PartyProfile profile,
          {PartyRole? primaryRole,
          Set<String> detailGroups = const {}}) async =>
      profile;
}

class _FakeDetailGroupRepository implements DetailGroupRepository {
  @override
  Future<void> disableGroup(String id) async {}
  @override
  Future<List<DetailGroup>> getGroups() async => const [
        DetailGroup(id: '20000', code: '20000', title: 'تأمین‌کنندگان'),
        DetailGroup(id: '30000', code: '30000', title: 'پرسنل'),
      ];
  @override
  Future<DetailGroup> saveGroup(
          {required String code, required String title, String? id}) async =>
      DetailGroup(id: id ?? code, code: code, title: title);
  @override
  Future<List<DetailGroup>> seedDefaults() => getGroups();
}
