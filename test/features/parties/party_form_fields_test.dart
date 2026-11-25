import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
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
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_local_record_store.dart';

class _CapturingPartyRepository implements PartyRepository {
  PartyProfile? saved;
  Object? failure;
  @override
  Future<PartyProfile> save(PartyProfile profile,
      {PartyRole? primaryRole, Set<String> detailGroups = const {}}) async {
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

class _Client extends Mock implements FrappeApiClient {}

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

Future<void> _open(
    WidgetTester tester, PartyRole role, PartyRepository repository,
    {double width = 390, PartyProfile? profile, bool canEditFinancial = true}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = _Client();
  when(() => client.isAuthenticated).thenReturn(false);
  when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
      .thenAnswer((_) async => {
            'can_edit_financial': canEditFinancial,
            'gender': ['Male', 'Female'],
            'employment_type': ['Full-time', 'Part-time'],
            'department': ['Sales'],
            'job_title': ['Sales Specialist'],
            'chart_jobs': [
              {'title': 'کارشناس فروش', 'department': 'Sales'},
            ],
            'bank': ['Bank'],
          });
  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: client),
      RepositoryProvider<PartyRepository>.value(value: repository),
      RepositoryProvider<DetailGroupRepository>.value(value: _Groups()),
    ],
    child: MaterialApp(
      theme: AsoudTheme.light,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PartyFormPage(
                        company: 'شرکت نمونه',
                        initialRole: role,
                        profile: profile))),
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
  testWidgets('personnel creation includes every reference field without opening-balance edits',
      (tester) async {
    await _open(tester, PartyRole.employee, _CapturingPartyRepository(), width: 320);
    for (final label in ['کد تفصیلی', 'پرسنل', 'مشتری', 'تأمین‌کننده',
      'بازاریاب', 'تنخواه‌گردان', 'فروشنده', 'صندوق']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    const sections = <String, List<String>>{
      'اطلاعات اصلی و هویتی': [
        'نام *', 'نام خانوادگی *', 'نام مستعار', 'کد ملی', 'جنسیت',
        'تاریخ تولد', 'شماره شناسنامه', 'نام پدر', 'محل صدور',
      ],
      'اطلاعات شغلی و سازمانی': [
        'نوع همکاری', 'تاریخ شروع همکاری', 'واحد سازمانی', 'سمت شغلی',
      ],
      'راه‌های ارتباطی': ['تلفن ثابت', 'تلفن دوم', 'ایمیل اصلی', 'وب‌سایت'],
      'آدرس و موقعیت': [
        'استان', 'شهر', 'نشانی کامل', 'منطقه', 'محله', 'پلاک', 'واحد',
        'کد پستی', 'عرض جغرافیایی', 'طول جغرافیایی',
      ],
      'اطلاعات مالی': [
        'سقف اعتبار (ریال)', 'مانده اول دوره هنگام استقرار', 'ندارد',
        'مانده بدهکار', 'مانده بستانکار', 'مبلغ',
      ],
      'اطلاعات بانکی': [
        'نام بانک', 'نام صاحب حساب', 'شماره شبا', 'شماره حساب', 'شماره کارت',
      ],
      'توضیحات': ['توضیحات تکمیلی (اختیاری)'],
    };
    for (final section in sections.entries) {
      await _expand(tester, section.key);
      for (final label in section.value) {
        expect(find.text(label), findsOneWidget, reason: '${section.key}: $label');
      }
      if (section.key == 'اطلاعات مالی') {
        expect(find.text('مانده بدهکار').hitTestable(), findsNothing);
        final amount = find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'مبلغ',
        );
        expect(tester.widget<AppTextField>(amount).readOnly, isTrue);
      }
      await _expand(tester, section.key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('personnel financial and bank fields remain hidden without permission',
      (tester) async {
    await _open(tester, PartyRole.employee, _CapturingPartyRepository(),
      canEditFinancial: false);
    expect(find.text('اطلاعات مالی'), findsNothing);
    expect(find.text('اطلاعات بانکی'), findsNothing);
  });

  testWidgets('new personnel can save with only first and last names', (tester) async {
    final repository = _CapturingPartyRepository();
    await _open(tester, PartyRole.employee, repository, width: 320);
    expect(find.text('راه‌های ارتباطی'), findsOneWidget);
    expect(find.text('آدرس و موقعیت'), findsOneWidget);
    expect(find.text('اطلاعات مالی'), findsOneWidget);
    await _expand(tester, 'اطلاعات اصلی و هویتی');
    Finder input(String label) => find.descendant(
      of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == label),
      matching: find.byType(TextFormField),
    );
    expect(input('شماره موبایل'), findsNothing);
    await tester.enterText(input('نام'), 'سارا');
    await tester.enterText(input('نام خانوادگی'), 'احمدی');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(repository.saved?.displayName, 'سارا احمدی');
    expect(repository.saved?.employeeGender, isNull);
    expect(repository.saved?.birthDate, isNull);
    expect(repository.saved?.dateOfJoining, isNull);
    expect(repository.saved?.province, isNull);
    expect(repository.saved?.city, isNull);
  });
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
        await _open(tester, PartyRole.employee, repository,
            width: width,
            profile:
                _validProfile(queued == 'pending existing' ? 'PARTY-1' : null));
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
      testWidgets('$kind keeps personnel form and values at $width',
          (tester) async {
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
      await _expand(tester, 'اطلاعات شغلی و سازمانی');
      final hint = find.text(
          'سمت‌ها از ساختار سازمانی همین دفتر خوانده می‌شوند. پس از انتخاب واحد، فقط سمت‌های همان واحد دیده می‌شوند.');
      expect(hint, findsOneWidget);
      expect(
          tester.getTopLeft(hint).dy,
          greaterThanOrEqualTo(tester
              .getBottomLeft(find.byType(AppSelectField).last)
              .dy));
      expect(tester.takeException(), isNull);
    });
    testWidgets('gender selection rebuilds at $width', (tester) async {
      await _open(tester, PartyRole.employee, _CapturingPartyRepository(),
          width: width);
      await tester.pumpAndSettle();
      await _expand(tester, 'اطلاعات اصلی و هویتی');
      final field = find.byType(AppSelectField).first;
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
    await _expand(tester, 'اطلاعات شغلی و سازمانی');

    expect(find.text('واحد سازمانی'), findsOneWidget);
    expect(find.text('سمت شغلی'), findsOneWidget);
    expect(find.byType(AppSelectField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the party form normalises Persian digits in the credit limit',
      (tester) async {
    final repository = _CapturingPartyRepository();
    await _open(tester, PartyRole.customer, repository);
    await _expand(tester, 'اطلاعات اصلی');
    Finder input(String label) => find.descendant(
      of: find.byWidgetPredicate((widget) => widget is AppTextField && widget.label == label),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(input('نام'), 'علی');
    await tester.enterText(input('نام خانوادگی'), 'رضایی');

    await _expand(tester, 'اطلاعات اصلی');
    await _expand(tester, 'اطلاعات مالی');
    // Persian digits must be parsed, otherwise creditLimit would be null.
    final creditField = find.byWidgetPredicate((widget) =>
        widget is AppTextField && widget.label.contains('سقف اعتبار'));
    await tester.enterText(
        find.descendant(
            of: creditField, matching: find.byType(TextFormField)),
        '۲۵۰۰۰۰۰۰');

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
      id: id,
      kind: PartyKind.individual,
      displayName: 'علی رضایی',
      roles: const {PartyRole.employee},
      employeeGender: 'Male',
      birthDate: '1992-05-11',
      dateOfJoining: '2024-04-21',
    );
