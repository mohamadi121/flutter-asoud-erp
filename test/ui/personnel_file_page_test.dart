import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(
        {String? code = 'HR-EMP-00042', bool canEdit = true}) =>
    {
      'profile_id': 'LOCAL-profile',
      'can_edit': canEdit,
      'header': {
        'name': 'امیر موفق',
        'employee_code': code,
        'designation': 'کارشناس فروش',
        'department_name': 'فروش',
        'status': 'Active',
        'employment_type': 'Full-time',
        'date_of_joining': '2020-01-01',
        'service_length': {'years': 6, 'months': 8},
      },
      'personal': {
        'national_id': '0012345678',
        'father_name': 'حسن',
        'birth_date': '1990-01-01',
        'employee_gender': 'Male',
        'marital_status': 'Married',
        'blood_group': 'O+',
        'mobile': '09121234567',
        'company_email': 'employee@example.com',
        'emergency': {
          'name': 'زهرا',
          'phone': '09121111111',
          'relation': 'همسر'
        },
        'education': [
          {
            'qualification': 'کارشناسی',
            'school': 'دانشگاه تهران',
            'major': 'مدیریت'
          }
        ],
        'previous_work': [
          {
            'company': 'شرکت پیشین',
            'designation': 'کارشناس',
            'experience': '۳ سال'
          }
        ],
      },
      'organization': {
        'company': 'تابان',
        'department_name': 'فروش',
        'department_path': ['بازرگانی', 'فروش'],
        'designation': 'کارشناس فروش',
        'branch': 'تهران',
        'employee_number': '42',
        'direct_reports': 2,
        'reports_to': {
          'name': 'محمد حسینی',
          'designation': 'مدیر فروش',
          'department_name': 'فروش'
        },
      },
      'employment': {
        'employment_type': 'Full-time',
        'date_of_joining': '2020-01-01',
        'status': 'Active',
        'service_length': {'years': 6, 'months': 8},
        'final_confirmation_date': '2020-04-01',
        'contract_end_date': '2026-12-31',
        'notice_number_of_days': 30,
        'holiday_list': 'تعطیلات رسمی',
        'default_shift': 'صبح',
      },
      'contracts': [
        {
          'name': 'C1',
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
          'state': 'active',
          'days_remaining': 97,
          'terms': 'قرارداد جاری',
          'file': {'id': 'F1', 'filename': 'contract.pdf'}
        },
        {
          'name': 'C0',
          'start_date': '2025-01-01',
          'end_date': '2025-12-31',
          'state': 'expired',
          'terms': 'قرارداد قبلی'
        },
      ],
      'salary': {
        'visible': true,
        'current': {
          'salary_structure': 'حقوق فروش',
          'base': 30000000,
          'variable': 1000000,
          'from_date': '2026-03-21'
        },
        'history': [
          {
            'salary_structure': 'حقوق قبلی',
            'base': 20000000,
            'from_date': '2025-03-21'
          }
        ],
        'latest_slip': {
          'start_date': '2026-08-01',
          'end_date': '2026-08-31',
          'gross_pay': 30000000,
          'total_deduction': 2100000,
          'net_pay': 27900000,
          'earnings': [
            {'component': 'حقوق پایه', 'amount': 30000000}
          ],
          'deductions': [
            {'component': 'بیمه', 'amount': 2100000}
          ]
        },
        'legacy': {'base_salary': '15000000'},
      },
      'documents': [
        {
          'id': 'D1',
          'title': 'کارت ملی',
          'category': 'Identity',
          'document_number': '0012345678',
          'issue_date': '2015-05-01',
          'expiry_date': '2026-10-01',
          'status': 'expiring',
          'filename': 'id.pdf'
        },
        {
          'id': 'D2',
          'title': 'دانشنامه',
          'category': 'Education',
          'status': 'valid'
        },
        {
          'id': 'D3',
          'title': 'گواهی اشتغال',
          'category': 'Employment',
          'status': 'expired'
        },
      ],
      'history': [
        {'kind': 'joining', 'title': 'شروع همکاری', 'date': '2020-01-01'},
        {'kind': 'contract', 'title': 'ثبت قرارداد', 'date': '2026-01-01'},
        {'kind': 'salary', 'title': 'تغییر حقوق', 'date': '2026-03-21'},
        {
          'kind': 'promotion',
          'title': 'ارتقا یا تغییر سمت',
          'date': '2026-09-25',
          'details': 'سرپرست فروش'
        },
      ],
      'attendance': {
        'present': 18,
        'absent': 0,
        'on_leave': 1,
        'half_day': 0,
        'late_entries': 2,
        'early_exits': 0,
        'last_checkin': {'time': '2026-09-25 08:02:00', 'log_type': 'IN'}
      },
      'leave': [
        {
          'leave_type': 'مرخصی استحقاقی',
          'remaining_leaves': 8,
          'total_leaves': 12,
          'leaves_taken': 3,
          'leaves_pending_approval': 1
        }
      ],
      'activity': [
        for (var i = 1; i <= 6; i++)
          {
            'title': 'فعالیت $i',
            'details': 'تغییر سمت',
            'by': 'مدیر منابع انسانی',
            'date': '2026-09-25 10:41:00'
          }
      ],
    };

class _Files extends Fake implements PersonnelFileRepository {
  _Files([Map<String, dynamic>? json])
      : value = PersonnelFile.fromJson(json ?? _fixture());
  PersonnelFile value;
  int reads = 0, mineReads = 0;
  bool fail = false;
  Map<String, dynamic>? saved;
  @override
  Future<PersonnelFile> file(String profileId) async {
    reads++;
    if (fail) {
      throw const ApiException(
          kind: ApiFailureKind.server, message: 'دریافت پرونده ناموفق بود');
    }
    return value;
  }

  @override
  Future<PersonnelFile> myFile() async {
    mineReads++;
    return value;
  }

  @override
  Future<List<ContractSummary>> saveContract(
      {required String profileId,
      required String startDate,
      required String terms,
      String? endDate,
      String? contract,
      bool isSigned = false,
      String? fileBase64,
      String? filename,
      bool submit = false}) async {
    saved = {
      'profileId': profileId,
      'startDate': startDate,
      'endDate': endDate,
      'terms': terms,
      'isSigned': isSigned,
      'submit': submit
    };
    return value.contracts;
  }
}

class _Personnel extends Fake implements PersonnelRepository {}

Widget _app(Widget page) => MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: page));

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String text) async {
  final target = find.widgetWithText(Tab, text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _start(WidgetTester tester, _Files repo,
    {bool mine = false, int initialTab = 0}) async {
  await tester.pumpWidget(_app(mine
      ? PersonnelFilePage.mine(
          repository: repo, personnel: _Personnel(), initialTab: initialTab)
      : PersonnelFilePage(
          profileId: 'LOCAL-profile',
          repository: repo,
          personnel: _Personnel(),
          initialTab: initialTab)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HR overview uses employee code, Jalali dates and summary cards',
      (tester) async {
    final repo = _Files();
    await _start(tester, repo);
    expect(repo.reads, 1);
    expect(find.text('HR-EMP-00042'), findsOneWidget);
    expect(find.textContaining('LOCAL'), findsNothing);
    for (final label in [
      'خلاصه اطلاعات',
      'واحد سازمانی',
      'مدیر مستقیم',
      'نوع همکاری',
      'تاریخ شروع همکاری',
      'قرارداد فعلی',
      'وضعیت مدارک',
      '۱۳۹۸/۱۰/۱۱',
      '۲ مورد نیازمند اقدام'
    ]) {
      await tester.ensureVisible(find.text(label).first);
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('ویرایش اطلاعات'), findsOneWidget);
    expect(find.text('عملیات بیشتر'), findsOneWidget);
    await tester.ensureVisible(find.text('فعالیت 5'));
    expect(find.text('فعالیت 6'), findsNothing);
    await _tap(tester, 'مشاهده همه');
    await tester.ensureVisible(find.text('فعالیت 6'));
    expect(find.text('فعالیت 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mine calls myFile and suppresses HR actions even with canEdit',
      (tester) async {
    final repo = _Files();
    await _start(tester, repo, mine: true);
    expect(repo.mineReads, 1);
    expect(repo.reads, 0);
    expect(find.text('اطلاعات من'), findsOneWidget);
    expect(find.text('ویرایش اطلاعات'), findsNothing);
    expect(find.text('عملیات بیشتر'), findsNothing);
    await _tab(tester, 'مدارک');
    expect(find.text('افزودن مدرک'), findsNothing);
    await _tab(tester, 'اطلاعات پرسنلی');
    await _tap(tester, 'قراردادها');
    expect(find.text('افزودن قرارداد'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await _tap(tester, 'حقوق و مزایا');
    expect(find.text('مبالغ ثبت‌شده پیش از حقوق و دستمزد'), findsNothing);
  });

  testWidgets('unlinked profile and denied editing', (tester) async {
    await _start(tester, _Files(_fixture(code: null, canEdit: false)));
    expect(find.text('در انتظار ثبت'), findsOneWidget);
    expect(find.textContaining('LOCAL'), findsNothing);
    expect(find.text('ویرایش اطلاعات'), findsNothing);
    expect(find.text('عملیات بیشتر'), findsNothing);
  });

  testWidgets('documents filter by category and open details', (tester) async {
    await _start(tester, _Files(), initialTab: 2);
    for (final text in ['رو به انقضا', 'معتبر', 'منقضی']) {
      await tester.ensureVisible(find.text(text));
      expect(find.text(text), findsOneWidget);
    }
    await _tap(tester, 'هویتی');
    expect(find.text('کارت ملی'), findsOneWidget);
    expect(find.text('دانشنامه'), findsNothing);
    expect(find.text('گواهی اشتغال'), findsNothing);
    await _tap(tester, 'کارت ملی');
    expect(find.text('جزئیات مدرک'), findsOneWidget);
    expect(find.text('0012345678'), findsOneWidget);
    await tester.ensureVisible(find.text('مشاهده/دانلود فایل'));
    expect(find.text('مشاهده/دانلود فایل'), findsOneWidget);
  });

  testWidgets('failed loading shows server message and retries',
      (tester) async {
    final repo = _Files()..fail = true;
    await _start(tester, repo);
    expect(find.text('دریافت پرونده ناموفق بود'), findsOneWidget);
    repo.fail = false;
    await _tap(tester, 'تلاش دوباره');
    expect(repo.reads, 2);
    expect(find.text('امیر موفق'), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('all tabs and section pages render with their data at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _start(tester, _Files());
      for (final tab in ['نمای کلی', 'مدارک', 'سوابق', 'اطلاعات پرسنلی']) {
        await _tab(tester, tab);
        if (tab == 'سوابق') {
          expect(find.text('ارتقا یا تغییر سمت'), findsOneWidget);
          expect(tester.getTopLeft(find.text('ارتقا یا تغییر سمت')).dy,
              lessThan(tester.getTopLeft(find.text('شروع همکاری')).dy));
        }
        expect(tester.takeException(), isNull);
      }
      final sections = {
        'اطلاعات فردی': [
          '0012345678',
          'مرد',
          'متأهل',
          'زهرا',
          'دانشگاه تهران',
          'شرکت پیشین',
          'کارت ملی'
        ],
        'اطلاعات سازمانی': [
          'تابان',
          'بازرگانی / فروش',
          'محمد حسینی',
          'زیرمجموعه مستقیم: ۲ نفر'
        ],
        'اطلاعات استخدامی': ['۱۳۹۸/۱۰/۱۱', 'تعطیلات رسمی', 'صبح'],
        'قراردادها': [
          'قرارداد جاری',
          '۹۷ روز مانده',
          'قرارداد قبلی',
          'مشاهده فایل'
        ],
        'حقوق و مزایا': [
          'حقوق فروش',
          '۳۰,۰۰۰,۰۰۰',
          '۲۷,۹۰۰,۰۰۰',
          'بیمه',
          'حقوق قبلی',
          'مبالغ ثبت‌شده پیش از حقوق و دستمزد'
        ],
        'حضور و غیاب': ['حاضر', '۱۸', 'ورود', 'مرخصی استحقاقی'],
      };
      for (final section in sections.entries) {
        await _tap(tester, section.key);
        expect(find.text(section.key), findsWidgets);
        for (final data in section.value) {
          await tester.ensureVisible(find.text(data).first);
          expect(find.text(data), findsWidgets);
          expect(tester.takeException(), isNull);
        }
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
      'contract terms required, valid form submits values and pops true',
      (tester) async {
    final repo = _Files();
    bool? result;
    await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                child: const Text('باز کردن'),
                onPressed: () async {
                  result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ContractFormPage(
                              profileId: 'LOCAL-profile', repository: repo)));
                })))));
    await _tap(tester, 'باز کردن');
    await _tap(tester, 'اطلاعات قرارداد');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'تاریخ شروع *'), '2026-01-01');
    await _tap(tester, 'ذخیره');
    expect(repo.saved, isNull);
    expect(find.text('شرح قرارداد الزامی است.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'تاریخ پایان'), '2026-12-31');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'شرح قرارداد *'), 'شرح همکاری');
    await _tap(tester, 'امضا شده');
    await _tap(tester, 'ثبت نهایی');
    await _tap(tester, 'ذخیره');
    expect(repo.saved, {
      'profileId': 'LOCAL-profile',
      'startDate': '2026-01-01',
      'endDate': '2026-12-31',
      'terms': 'شرح همکاری',
      'isSigned': true,
      'submit': true
    });
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
