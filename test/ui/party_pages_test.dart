import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(find.text('گروه تفصیلی'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('اطلاعات شغلی'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('اطلاعات شغلی'), findsOneWidget);
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
          {PartyRole? primaryRole, String? detailGroup}) async =>
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
