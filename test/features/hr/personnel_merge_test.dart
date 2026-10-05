import 'package:asoud_erp/features/parties/domain/entities/party_profile.dart';
import 'package:asoud_erp/features/parties/domain/repositories/party_repository.dart';
import 'package:asoud_erp/features/parties/presentation/pages/party_form_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _sections = [
  'اطلاعات فردی',
  'اطلاعات سازمانی',
  'اطلاعات استخدامی',
  'قراردادها',
  'حقوق و مزایا',
  'حضور و غیاب',
];

Map<String, dynamic> _fileFixture(
        {String profileId = 'PARTY-1',
        String? code = 'HR-EMP-00042',
        String joining = '2024-03-20',
        String? photo}) =>
    {
      'profile_id': profileId,
      'can_edit': true,
      'header': {
        'name': 'سارا کریمی',
        'employee_code': code,
        'designation': 'کارشناس فروش',
        'department_name': 'فروش',
        'company': 'تابان',
        'status': 'Active',
        'employment_type': 'Full-time',
        'date_of_joining': joining,
        'photo_record': photo,
        'service_length': {'years': 2, 'months': 1},
      },
      'organization': {
        'company': 'تابان',
        'designation': 'کارشناس فروش',
        'department_name': 'فروش',
        'reports_to': {
          'employee': 'PARTY-9',
          'name': 'محمد حسینی',
          'designation': 'مدیر فروش',
        }
      },
      'contracts': [
        {
          'name': 'C1',
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
          'state': 'active',
          'days_remaining': 97,
          'terms': 'قرارداد جاری'
        }
      ],
      'documents': [
        {
          'id': 'D1',
          'title': 'کارت ملی',
          'category': 'Identity',
          'status': 'expiring'
        },
        {
          'id': 'D2',
          'title': 'گواهی اشتغال',
          'category': 'Employment',
          'status': 'expired'
        },
      ],
      'history': [
        {'kind': 'joining', 'title': 'شروع همکاری', 'date': '2024-03-20'},
      ],
      'activity': [
        {
          'title': 'ثبت قرارداد',
          'details': 'تمدید یک‌ساله',
          'by': 'مدیر منابع انسانی',
          'date': '2026-09-25 10:41:00'
        },
        {
          'title': 'تغییر سمت',
          'details': 'سرپرست فروش',
          'by': 'مدیر منابع انسانی',
          'date': '2026-08-02 09:00:00'
        },
      ],
    };

class Files extends Fake implements PersonnelFileRepository {
  Files([Map<String, dynamic>? json])
      : value = PersonnelFile.fromJson(json ?? _fileFixture());
  PersonnelFile value;
  int reads = 0;
  String? lastId;
  @override
  Future<PersonnelFile> file(String id) async {
    reads++;
    lastId = id;
    return value;
  }
}

class People extends Fake implements PersonnelRepository {
  int reads = 0;
  @override
  Future<Map<String, dynamic>> record(String id) async {
    reads++;
    return {'file': '', 'filename': '$id.jpg'};
  }
}

/// Stands in for the older `get_personnel` detail payload the merged page
/// still reads for sync state, retry, importing local records and per-section
/// profile editing.
class SyncPeople extends Fake implements PersonnelRepository {
  bool failed = true;
  int retries = 0;
  String? imported;
  String? revision;
  Map<String, dynamic>? edited;
  int details = 0;
  @override
  bool get localDemo => true;
  @override
  Future<Map<String, dynamic>> detail(String id) async {
    details++;
    return {
      'profile': {
        'id': id,
        'display_name': 'سارا کریمی',
        'job_title': 'کارشناس فروش',
        'department': 'فروش',
        'employment_type': 'تمام وقت',
        'branch': 'تهران',
        'reports_to': 'PARTY-9',
      },
      'revision': 'revision-7',
      'can_edit': true,
      'records': [
        {
          'name': 'R1',
          'kind': 'education',
          'title': 'کارشناسی مدیریت',
          'record_date': '2016-09-01'
        },
        {
          'name': 'R2',
          'kind': 'experience',
          'title': 'کارشناس فروش در تابان',
          'record_date': '2019-03-01'
        },
      ],
      'offline': true,
      'pending_sync': true,
      'sync_failed': failed,
    };
  }

  @override
  Future<void> retryFailed(String id) async {
    retries++;
    failed = false;
  }

  @override
  Future<List<Map<String, dynamic>>> localImportCandidates() async => [
        {
          'id': 'LOCAL-source',
          'display_name': 'پرونده محلی',
          'national_id': '123'
        }
      ];

  @override
  Future<void> importLocalRecords(String source, String target) async {
    imported = '$source->$target';
  }

  @override
  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> values, String revision) async {
    this.revision = revision;
    edited = values;
    return detail(id);
  }
}

class MasterPeople extends Fake implements PartyRepository {
  int lists = 0;
  @override
  Future<List<PartyProfile>> list(
      {String? company, PartyRole? role, String? search}) async {
    lists++;
    return [
      PartyProfile(
          id: 'PARTY-0',
          company: 'تابان',
          kind: PartyKind.individual,
          displayName: 'شخص دیگر',
          roles: const {PartyRole.employee}),
      PartyProfile(
          id: 'PARTY-1',
          company: 'تابان',
          kind: PartyKind.individual,
          displayName: 'سارا کریمی',
          nationalId: '0012345678',
          roles: const {PartyRole.employee}),
    ];
  }
}

class Pushes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

/// `pumpAndSettle` never settles while a busy progress indicator animates, so
/// interactions with the import sheet use fixed pumps instead.
Future<void> tap(WidgetTester tester, String label,
    {bool settle = true}) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapSheet(WidgetTester tester, String label) async {
  final target = find.widgetWithText(ListTile, label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.widgetWithText(Tab, label));
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// Providers must sit above `MaterialApp`: a route pushed on the app navigator
/// becomes a sibling of `home`, so anything provided inside `home` is invisible
/// to it.
Future<void> start(WidgetTester tester, Widget page,
    {Pushes? observer, MasterPeople? master}) async {
  await tester.pumpWidget(RepositoryProvider<PartyRepository>.value(
      value: master ?? MasterPeople(),
      child: MaterialApp(
          navigatorObservers: [if (observer != null) observer],
          home: Builder(
              builder: (context) => Directionality(
                  textDirection: TextDirection.rtl, child: page)))));
  await tester.pumpAndSettle();
  // The home route itself is a push; only later pushes are interesting.
  observer?.pushed.clear();
}

void main() {
  testWidgets('a list row opens the personnel file and nothing else',
      (tester) async {
    final observer = Pushes();
    final files = Files();
    final list = PersonnelListProbe(files: files);
    await start(tester, list, observer: observer);
    expect(observer.pushed, isEmpty, reason: 'the list itself pushes nothing');
    await tap(tester, 'سارا کریمی');
    expect(observer.pushed, hasLength(1), reason: 'exactly one route');
    expect(files.lastId, 'PARTY-1');
    expect(find.text('پرونده پرسنلی'), findsOneWidget);
    expect(find.byType(PersonnelFilePage), findsOneWidget);
  });

  testWidgets('«ویرایش پرونده» switches tab and pushes no route',
      (tester) async {
    final observer = Pushes();
    await start(
        tester,
        PersonnelFilePage(
            profileId: 'PARTY-1', repository: Files(), personnel: People()),
        observer: observer);
    await tap(tester, 'ویرایش پرونده');
    expect(observer.pushed, isEmpty, reason: 'no new page');
    expect(find.widgetWithText(Tab, 'اطلاعات پرسنلی'), findsOneWidget);
    expect(find.text('اطلاعات فردی'), findsOneWidget);
    expect(find.text('پرونده پرسنلی'), findsOneWidget);
  });

  testWidgets('tabs are exactly نمای کلی، اطلاعات پرسنلی، سوابق، مدارک',
      (tester) async {
    await start(
        tester,
        PersonnelFilePage(
            profileId: 'PARTY-1', repository: Files(), personnel: People()));
    expect(tester.widgetList<Tab>(find.byType(Tab)).map((e) => e.text).toList(),
        ['نمای کلی', 'اطلاعات پرسنلی', 'سوابق', 'مدارک']);
  });

  testWidgets('initialTab 3 lands on «مدارک»', (tester) async {
    await start(
        tester,
        PersonnelFilePage(
            profileId: 'PARTY-1',
            repository: Files(),
            personnel: People(),
            initialTab: 3));
    expect(find.text('افزودن مدرک'), findsOneWidget);
    expect(find.text('کارت ملی'), findsOneWidget);
    // Tab labels stay mounted, so the selected index is what proves the landing.
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
  });

  group('header', () {
    testWidgets('shows photo-or-initials, identity and the employee code',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      expect(find.text('کد پرسنلی'), findsOneWidget);
      expect(find.text('HR-EMP-00042'), findsOneWidget);
      expect(find.text('فعال'), findsOneWidget);
      expect(find.text('سارا کریمی'), findsOneWidget);
      expect(find.text('کارشناس فروش'), findsWidgets);
      expect(find.text('فروش'), findsWidgets);
      expect(find.text('س ک'), findsOneWidget, reason: 'initials fallback');
    });

    testWidgets('a local person shows «در انتظار ثبت» and never the raw id',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'LOCAL-1789239',
              repository: Files(_fileFixture(
                  profileId: 'LOCAL-1789239', code: 'LOCAL-1789239')),
              personnel: People()));
      expect(find.text('در انتظار ثبت'), findsOneWidget);
      expect(find.textContaining('LOCAL-'), findsNothing);
    });
  });

  group('overview', () {
    testWidgets('has exactly the six summary tiles, two per row',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      const labels = [
        'مدیر مستقیم',
        'نوع همکاری',
        'تاریخ شروع همکاری',
        'سابقه خدمت',
        'قرارداد جاری',
        'وضعیت مدارک',
      ];
      for (final label in labels) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(top(labels[0]), top(labels[1]));
      expect(top(labels[2]), top(labels[3]));
      expect(top(labels[4]), top(labels[5]));
      expect(top(labels[2]), greaterThan(top(labels[0])));
    });

    testWidgets('the joining date tile is Jalali with Persian digits',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      expect(find.text('۱۴۰۳/۰۱/۰۱'), findsOneWidget);
      expect(find.text('ثبت نشده'), findsNothing);
    });

    testWidgets('an empty joining date reads «ثبت نشده», never a dash',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(_fileFixture(joining: '')),
              personnel: People()));
      await tester.ensureVisible(find.text('تاریخ شروع همکاری'));
      expect(find.text('ثبت نشده'), findsOneWidget);
    });

    testWidgets('the contract tile shows its state chip, end date and days',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.ensureVisible(find.text('قرارداد جاری'));
      expect(find.text('در جریان'), findsOneWidget);
      expect(find.textContaining('۹۷ روز مانده'), findsOneWidget);
      expect(find.textContaining('۱۴۰۵/۱۰/۱۰'), findsWidgets);
    });

    testWidgets('the documents tile counts what needs action', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.ensureVisible(find.text('وضعیت مدارک'));
      expect(find.text('۲ مورد نیازمند اقدام'), findsOneWidget);
    });

    testWidgets('the manager tile opens that manager file', (tester) async {
      final files = Files();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: files, personnel: People()));
      await tester.ensureVisible(find.text('مدیر مستقیم'));
      await tester.tap(find.text('مدیر مستقیم'));
      await tester.pumpAndSettle();
      expect(files.lastId, 'PARTY-9');
      expect(find.text('پرونده پرسنلی'), findsOneWidget);
    });

    testWidgets('the documents tile opens the مدارک tab', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.ensureVisible(find.text('وضعیت مدارک'));
      await tester.tap(find.text('وضعیت مدارک'));
      await tester.pumpAndSettle();
      expect(find.text('افزودن مدرک'), findsOneWidget);
    });

    testWidgets('the contract tile opens the قراردادها section',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.ensureVisible(find.text('قرارداد جاری'));
      await tester.tap(find.text('قرارداد جاری'));
      await tester.pumpAndSettle();
      expect(find.text('سوابق قراردادها'), findsOneWidget);
      expect(find.text('افزودن قرارداد'), findsOneWidget);
    });

    testWidgets('recent activity shows «توسط», the Jalali moment and an icon',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      final activity = find.text('ثبت قرارداد');
      await tester.ensureVisible(activity);
      final card = find.ancestor(of: activity, matching: find.byType(Card));
      expect(
          find.descendant(
              of: card,
              matching: find.textContaining('توسط مدیر منابع انسانی')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.textContaining('۱۴۰۵/۰۷/۰۳')),
          findsOneWidget);
      expect(
          find.descendant(of: card, matching: find.byIcon(Icons.description)),
          findsOneWidget);
    });
  });

  group('account menu', () {
    testWidgets('the file menu and the list row share one item list',
        (tester) async {
      // One declaration feeds both the list row and the file page.
      expect(personnelAccountMenuEntries.map((e) => e.title), [
        'مدیریت دسترسی',
        'ایجاد/تغییر حساب کاربری',
        'ارسال مجدد دعوت',
        'مشاهده سوابق ورود',
      ]);
      expect(personnelAccountMenuEntries.map((e) => e.title),
          isNot(contains('حذف حساب کاربری')));

      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.tap(find.byTooltip('مدیریت دسترسی'));
      await tester.pumpAndSettle();
      expect(find.text('حذف حساب کاربری'), findsNothing);
      for (final title in [
        'مدیریت دسترسی',
        'ایجاد/تغییر حساب کاربری',
        'ارسال مجدد دعوت',
        'مشاهده سوابق ورود'
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('an action without an API explains itself in Persian',
        (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tester.tap(find.byTooltip('مدیریت دسترسی'));
      await tester.pumpAndSettle();
      await tap(tester, 'مشاهده سوابق ورود');
      expect(
          find.text('این قابلیت هنوز به سرویس متصل نشده است.'), findsOneWidget);
    });

    testWidgets('the menu is hidden when the viewer cannot manage',
        (tester) async {
      await start(tester,
          PersonnelFilePage.mine(repository: Files(), personnel: People()));
      expect(find.text('اطلاعات من'), findsOneWidget);
      expect(find.byTooltip('مدیریت دسترسی'), findsNothing);
      expect(find.text('ویرایش پرونده'), findsNothing);
      expect(find.text('عملیات بیشتر'), findsNothing);
    });
  });

  group('information tab', () {
    testWidgets('«اطلاعات فردی» is read-only and edits the person master',
        (tester) async {
      final master = MasterPeople();
      final observer = Pushes();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: People(),
              initialTab: 1),
          observer: observer,
          master: master);
      await tap(tester, 'اطلاعات فردی');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('ویرایش اطلاعات شخص'), findsOneWidget);
      await tap(tester, 'ویرایش اطلاعات شخص');
      expect(master.lists, greaterThan(0));
      expect(find.byType(PartyFormPage), findsOneWidget);
      expect(find.text('ویرایش اطلاعات شخص'), findsWidgets);
      // The section page, then the person-master form on top of it.
      expect(observer.pushed, hasLength(2));
    });

    testWidgets('«اطلاعات سازمانی» edits its own fields with the revision',
        (tester) async {
      final people = SyncPeople();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: people,
              initialTab: 1));
      await tap(tester, 'اطلاعات سازمانی');
      await tap(tester, 'ویرایش اطلاعات');
      await tester.tap(find.widgetWithText(ExpansionTile, 'اطلاعات سازمانی'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'سمت'), 'مدیر فروش');
      await tap(tester, 'ذخیره');
      expect(people.revision, 'revision-7');
      expect(people.edited!['job_title'], 'مدیر فروش');
      expect(people.edited!.keys.toSet(),
          {'job_title', 'department', 'branch', 'reports_to'});
    });

    testWidgets('«اطلاعات استخدامی» edits only employment fields',
        (tester) async {
      final people = SyncPeople();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: people,
              initialTab: 1));
      await tap(tester, 'اطلاعات استخدامی');
      await tap(tester, 'ویرایش اطلاعات');
      await tester.tap(find.widgetWithText(ExpansionTile, 'اطلاعات سازمانی'));
      await tester.pumpAndSettle();
      await tap(tester, 'ذخیره');
      expect(people.edited!.keys.toSet(), {
        'date_of_joining',
        'employment_type',
        'final_confirmation_date',
        'contract_end_date',
        'notice_number_of_days',
      });
    });

    testWidgets('«حقوق و مزایا» edits the benefit fields only', (tester) async {
      final people = SyncPeople();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: people,
              initialTab: 1));
      await tap(tester, 'حقوق و مزایا');
      await tap(tester, 'ثبت و ویرایش حقوق و مزایا');
      await tester.tap(find.widgetWithText(ExpansionTile, 'حقوق و مزایا'));
      await tester.pumpAndSettle();
      await tap(tester, 'ذخیره');
      expect(people.edited!.keys.toSet(), {
        'base_salary',
        'housing_allowance',
        'transport_allowance',
        'other_allowances',
        'deductions',
        'net_salary',
      });
    });
  });

  group('records tab', () {
    testWidgets('shows the timeline and the record kinds', (tester) async {
      final observer = Pushes();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: SyncPeople(),
              initialTab: 2),
          observer: observer);
      expect(find.text('شروع همکاری'), findsOneWidget);
      for (final kind in [
        'کارکرد و سوابق حضور',
        'مدارک و مستندات',
        'ارزیابی عملکرد',
        'تاریخچه',
        'تصویر پرسنل'
      ]) {
        await tester.ensureVisible(find.text(kind));
        expect(find.text(kind), findsOneWidget, reason: kind);
      }
      expect(observer.pushed, isEmpty, reason: 'the tab pushes nothing');
    });

    testWidgets('a record kind opens its list and adds a record',
        (tester) async {
      final observer = Pushes();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: SyncPeople(),
              initialTab: 2),
          observer: observer);
      await tap(tester, 'کارکرد و سوابق حضور');
      expect(find.text('ثبت مورد جدید'), findsOneWidget);
      await tap(tester, 'ثبت مورد جدید');
      expect(observer.pushed, hasLength(2));
      expect(find.text('ثبت کارکرد و سوابق حضور'), findsOneWidget);
    });

    testWidgets('«مشاهده سوابق» lists every kind together', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: SyncPeople(),
              initialTab: 2));
      await tap(tester, 'مشاهده سوابق');
      expect(find.text('سوابق و فعالیت‌ها'), findsWidgets);
      expect(find.text('کارشناسی مدیریت'), findsOneWidget);
      expect(find.text('کارشناس فروش در تابان'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget, reason: 'search box');
    });
  });

  group('capabilities carried over', () {
    testWidgets('sync notice stays on top and retries failed sends',
        (tester) async {
      final people = SyncPeople();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: people));
      expect(find.text('همگام‌سازی نیازمند بررسی است'), findsOneWidget);
      expect(find.text('تلاش مجدد برای همگام‌سازی'), findsOneWidget);
      await tap(tester, 'تلاش مجدد برای همگام‌سازی');
      expect(people.retries, 1);
      expect(find.text('ذخیره روی گوشی؛ در انتظار همگام‌سازی'), findsOneWidget);
    });

    testWidgets('«انتقال سوابق پرسنل محلی» moves local records',
        (tester) async {
      final people = SyncPeople();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: people));
      await tap(tester, 'عملیات بیشتر');
      await tapSheet(tester, 'انتقال سوابق پرسنل محلی');
      await tapSheet(tester, 'پرونده محلی');
      await tap(tester, 'تأیید انتقال', settle: false);
      await tester.pumpAndSettle();
      expect(people.imported, 'LOCAL-source->PARTY-1');
      expect(
          find.text('انتقال ثبت شد؛ وضعیت ارسال در پرونده نمایش داده می‌شود.'),
          findsOneWidget);
    });

    testWidgets('«عملیات بیشتر» holds only HR actions', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1', repository: Files(), personnel: People()));
      await tap(tester, 'عملیات بیشتر');
      for (final action in [
        'افزودن قرارداد',
        'ثبت ارتقا یا تغییر سمت',
        'افزودن مدرک',
        'انتقال سوابق پرسنل محلی'
      ]) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
      for (final account in [
        'مدیریت دسترسی',
        'ایجاد/تغییر حساب کاربری',
        'ارسال مجدد دعوت'
      ]) {
        expect(find.text(account), findsNothing, reason: account);
      }
    });

    testWidgets('a photo record replaces the initials', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(_fileFixture(photo: 'PHOTO-1')),
              personnel: People()));
      expect(find.text('س ک'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('«افزودن مدرک» opens the document record form', (tester) async {
      final observer = Pushes();
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: People(),
              initialTab: 3),
          observer: observer);
      await tap(tester, 'افزودن مدرک');
      expect(observer.pushed, hasLength(1));
      expect(find.text('ثبت مدارک و مستندات'), findsOneWidget);
    });

    testWidgets('a document opens its detail page', (tester) async {
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: People(),
              initialTab: 3));
      await tap(tester, 'کارت ملی');
      expect(find.text('جزئیات مدرک'), findsOneWidget);
      expect(find.text('هویتی'), findsOneWidget);
    });
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('the merged file and its sections render at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await start(
          tester,
          PersonnelFilePage(
              profileId: 'PARTY-1',
              repository: Files(),
              personnel: SyncPeople()));
      expect(tester.takeException(), isNull);
      for (final label in ['نمای کلی', 'اطلاعات پرسنلی', 'سوابق', 'مدارک']) {
        await tab(tester, label);
        expect(tester.takeException(), isNull, reason: label);
      }
      for (final section in _sections) {
        await tab(tester, 'اطلاعات پرسنلی');
        await tap(tester, section);
        expect(find.text(section), findsWidgets, reason: section);
        expect(tester.takeException(), isNull, reason: section);
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
        await tester.pumpAndSettle();
      }
    });
  }
}

/// A stand-in for the personnel list so the row tap can be exercised without
/// booting the whole cubit stack.
class PersonnelListProbe extends StatelessWidget {
  const PersonnelListProbe({super.key, required this.files});
  final Files files;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          body: ListView(children: [
        for (final person in const [
          {'id': 'PARTY-1', 'display_name': 'سارا کریمی'},
          {'id': 'PARTY-2', 'display_name': 'علی رضایی'},
        ])
          ListTile(
              title: Text('${person['display_name']}'),
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => PersonnelFilePage(
                          profileId: '${person['id']}',
                          repository: files,
                          personnel: People())))),
      ])));
}
