import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/features/accounting/domain/entities/detail_group.dart';
import 'package:asoud_erp/features/accounting/domain/repositories/detail_group_repository.dart';
import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingPartyRepository implements PartyRepository {
  PartyProfile? saved;
  @override
  Future<PartyProfile> save(PartyProfile profile,
      {PartyRole? primaryRole,
      Set<String> detailGroups = const {}}) async {
    saved = profile;
    return profile;
  }

  @override
  Future<FloatingDetail> createDetail(
          {required String title,
          required String type,
          required String detailGroup,
          required String profileId}) async =>
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
}

class _Groups implements DetailGroupRepository {
  @override
  Future<void> disableGroup(String id) async {}
  @override
  Future<List<DetailGroup>> getGroups() async => const [
        DetailGroup(id: 'people', code: '01000', title: 'اشخاص و شرکت‌ها'),
        DetailGroup(id: '30000', code: '30000', title: 'پرسنل'),
      ];
  @override
  Future<DetailGroup> saveGroup(
          {required String code, required String title, String? id}) async =>
      DetailGroup(id: id ?? code, code: code, title: title);
  @override
  Future<List<DetailGroup>> seedDefaults() => getGroups();
}

Future<void> _open(WidgetTester tester, PartyRole role,
    _CapturingPartyRepository repository) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<PartyRepository>.value(value: repository),
      RepositoryProvider<DetailGroupRepository>.value(value: _Groups()),
    ],
    child: MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PartyFormPage(
                        company: 'شرکت نمونه', initialRole: role))),
                child: const Text('باز کردن'),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
}

Future<void> _expand(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the employee party form uses AppTextField and AppSelectField',
      (tester) async {
    await _open(tester, PartyRole.employee, _CapturingPartyRepository());
    await _expand(tester, 'اطلاعات شغلی و بانکی');

    expect(find.text('جنسیت *'), findsOneWidget);
    expect(find.byType(AppSelectField), findsOneWidget);
    // The opening balance amount became a shared field with the ریال suffix.
    expect(find.widgetWithText(AppTextField, 'مبلغ'), findsOneWidget);
    expect(find.text('ریال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the party form normalises Persian digits in the credit limit',
      (tester) async {
    final repository = _CapturingPartyRepository();
    await _open(tester, PartyRole.customer, repository);
    await _expand(tester, 'اطلاعات اصلی');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'نام *'), 'علی');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'نام خانوادگی *'), 'رضایی');

    await _expand(tester, 'اطلاعات مالی و بانکی');
    // Persian digits must be parsed, otherwise creditLimit would be null.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'سقف اعتبار'), '۲۵۰۰۰۰۰۰');

    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.displayName, 'علی رضایی');
    expect(repository.saved!.creditLimit, 25000000);
    expect(tester.takeException(), isNull);
  });
}
