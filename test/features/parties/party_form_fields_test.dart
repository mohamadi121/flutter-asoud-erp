import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/features/parties/data/repositories/server_first_party_repository.dart';
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

import '../../helpers/fake_local_record_store.dart';

class _CapturingPartyRepository implements PartyRepository {
  PartyProfile? saved;
  Object? failure;
  @override
  Future<PartyProfile> save(PartyProfile profile,
      {PartyRole? primaryRole,
      Set<String> detailGroups = const {}}) async {
    saved = profile;
    if (failure != null) throw failure!;
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
    PartyRepository repository, {double width = 390, PartyProfile? profile}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<PartyRepository>.value(value: repository),
      RepositoryProvider<DetailGroupRepository>.value(value: _Groups()),
    ],
    child: MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PartyFormPage(
                        company: 'شرکت نمونه', initialRole: role, profile: profile))),
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
  for (final width in [320.0, 390.0, 430.0]) {
    for (final queued in ['exception', 'pending new', 'pending existing']) {
      testWidgets('$queued save waits for notice then closes at $width',
          (tester) async {
        final remote = _CapturingPartyRepository()
          ..failure = queued == 'exception'
              ? const QueuedOfflineException(localId: 'queued-party')
              : const ApiException(
                  kind: ApiFailureKind.network, message: 'offline');
        final repository = queued == 'exception'
            ? remote
            : ServerFirstPartyRepository(remote, local: FakeLocalRecordStore());
        await _open(tester, PartyRole.employee, repository, width: width,
            profile: _validProfile(
                queued == 'pending existing' ? 'PARTY-1' : null));
        await tester.tap(find.text('ذخیره'));
        // The saving spinner remains active behind the modal notice.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_queuedNotice), findsOneWidget);
        expect(find.byType(PartyFormPage), findsOneWidget);
        await tester.tap(find.text('باشه'));
        await tester.pumpAndSettle();
        expect(find.byType(PartyFormPage), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
    for (final kind in [ApiFailureKind.forbidden, ApiFailureKind.validation]) {
      testWidgets('$kind keeps personnel form and values at $width', (tester) async {
        final failure = ApiException(
            kind: kind,
            statusCode: kind == ApiFailureKind.forbidden ? 403 : 417,
            message: 'سمت شغلی ثبت نشده است.');
        final repository = _CapturingPartyRepository()..failure = failure;
        await _open(tester, PartyRole.employee, repository,
            width: width, profile: _validProfile('PARTY-1'));
        await tester.tap(find.text('ذخیره'));
        await tester.pumpAndSettle();
        expect(find.byType(PartyFormPage), findsOneWidget);
        expect(find.text(failureMessage(failure)), findsOneWidget);
        await _expand(tester, 'اطلاعات اصلی');
        expect(find.widgetWithText(TextFormField, 'علی'), findsOneWidget);
        expect(find.text(_queuedNotice), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('designation hint fits below both fields at $width',
        (tester) async {
      await _open(tester, PartyRole.employee, _CapturingPartyRepository(),
          width: width);
      await _expand(tester, 'اطلاعات اصلی');
      final hint = find.text(
          'سمت باید از سمت‌های ثبت‌شده در سرور باشد؛ اگر مطمئن نیستید خالی بگذارید.');
      expect(hint, findsOneWidget);
      expect(
          tester.getTopLeft(hint).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(
              find.widgetWithText(AppTextField, 'واحد سازمانی')).dy));
      expect(tester.takeException(), isNull);
    });
    testWidgets('gender selection rebuilds at $width', (tester) async {
      await _open(tester, PartyRole.employee, _CapturingPartyRepository(),
          width: width);
      await tester.pumpAndSettle();
      await _expand(tester, 'اطلاعات شغلی و بانکی');
      final field = find.byType(AppSelectField);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('مرد').last);
      await tester.pumpAndSettle();
      expect(tester.widget<AppSelectField>(field).displayValue, 'مرد');
      expect(tester.takeException(), isNull);
    });
  }

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

const _queuedNotice = 'ذخیره روی گوشی انجام شد و هنوز به سرور ارسال نشده است';
PartyProfile _validProfile(String? id) => PartyProfile(
  id: id, kind: PartyKind.individual, displayName: 'علی رضایی',
  roles: const {PartyRole.employee}, employeeGender: 'Male',
  birthDate: '1992-05-11', dateOfJoining: '2024-04-21',
);
