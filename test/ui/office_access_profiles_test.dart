import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/auth/personnel_representation.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/roles/data/access_management_repository.dart';
import 'package:asoud_erp/features/roles/presentation/access_profiles_page.dart';
import 'package:asoud_erp/features/roles/presentation/office_users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const catalog = <AccessMap>[
  {
    'module': 'مالی',
    'group': 'ثبت حسابداری',
    'doctype': 'Journal Entry',
    'title': 'سند حسابداری',
    'actions': ['read', 'create', 'write', 'delete'],
    'details': []
  },
  {
    'module': 'مالی',
    'group': 'ثبت حسابداری',
    'doctype': 'Account',
    'title': 'کدینگ',
    'actions': ['read'],
    'details': []
  },
];

class Client extends Fake implements FrappeApiClient {}

class Repo extends AccessManagementRepository {
  Repo() : super(Client());
  final writes = <Map<String, dynamic>>[];
  List<AccessMap> people = [];
  bool deleted = false;
  bool pending = false;
  AccessMap? layout;
  static const activation = {
    'method': 'manual_code',
    'code': 'H2K5D6F8G9',
    'login': 'sara@example.com',
    'expires_in_hours': 72
  };
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    if (method == 'list_accounts') return people;
    if (method == 'list_profiles') {
      return {
        'catalog': catalog,
        if (layout != null) 'catalog_layout': layout,
        'profiles': [
          if (!deleted)
            {
              'name': 'PROFILE',
              'title': 'حسابدار',
              'description': '',
              'company': 'دفتر الف',
              'readonly': false,
              'modified': 'stamp',
              'grants': {
                'Journal Entry': ['read', 'create']
              }
            },
        ],
        'examples': [
          {'title': 'حسابدار'}
        ]
      };
    }
    if (method == 'get_account') {
      return {
        'employee': 'EMP',
        'title': 'سارا احمدی',
        'designation': 'کارشناس اداری',
        'company': 'دفتر الف',
        'user': 'sara@example.com',
        'legacy': false,
        'profile': null,
        'token': 'stamp',
        'catalog': catalog,
        'activation_pending': pending,
        'grants': {
          'Account': ['read']
        }
      };
    }
    writes.add({'endpoint': method, ...args});
    if (method == 'save_catalog_layout') {
      return layout = {
        'modules': args['modules'],
        'version': 'saved',
        'editable': true
      };
    }
    if (method == 'delete_profile') deleted = true;
    if (args['delivery'] == 'manual_code') {
      return method == 'create_account'
          ? {'activation': activation}
          : activation;
    }
    return {};
  }
}

Widget app(Widget child) => MaterialApp(
    theme: AsoudTheme.light,
    builder: (_, c) =>
        Directionality(textDirection: TextDirection.rtl, child: c!),
    home: child);

Future<void> expandMatrix(WidgetTester tester) async {
  for (final label in ['مالی', 'ثبت حسابداری']) {
    final entry = find.text(label);
    await Scrollable.ensureVisible(tester.element(entry), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(entry.hitTestable());
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('representation requires a server-approved row and a reason',
      (tester) async {
    final repo = Repo()..people = [
      {'name': 'EMP-1', 'employee_name': 'صبا تستی', 'user_id': 'saba@example.com',
        'account_status': 'active', 'can_represent': true},
      {'name': 'EMP-2', 'employee_name': 'بدون نشست', 'account_status': 'no_account',
        'can_represent': false},
    ];
    (String, String, String)? selected;
    await tester.pumpWidget(app(RepositoryProvider.value(
      value: PersonnelRepresentationLauncher((_, office, employee, reason) async {
        selected = (office, employee, reason);
      }),
      child: OfficeUsersPage(company: 'دفتر الف', repository: repo),
    )));
    await tester.pumpAndSettle();
    expect(find.byTooltip('گزینه‌های بدون نشست'), findsNothing);
    await tester.tap(find.byTooltip('گزینه‌های صبا تستی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ورود به نمایندگی از پرسنل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ورود و اقدام به نمایندگی'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.enterText(find.byType(TextFormField), 'پیگیری درخواست کارتابل');
    await tester.tap(find.text('ورود و اقدام به نمایندگی'));
    await tester.pumpAndSettle();
    expect(selected, ('دفتر الف', 'EMP-1', 'پیگیری درخواست کارتابل'));
  });

  testWidgets('shared catalog adds edits and removes rows at three levels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = Repo()
      ..layout = {'modules': [], 'version': 'initial', 'editable': true};
    Future<void> tap(Finder target) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> name(String value) async {
      final input = find.widgetWithText(TextFormField, 'نام ردیف');
      await tester.enterText(input, value);
      await tap(find.text('تأیید'));
    }

    await tester.pumpWidget(
        app(AccessProfilesPage(company: 'دفتر الف', repository: repo)));
    await tester.pumpAndSettle();
    await tap(find.text('پروفایل جدید'));
    await tap(find.text('مدیریت کاتالوگ مشترک'));
    await tap(find.text('افزودن ماژول'));
    await name('مکاتبات');
    await tap(find.text('مکاتبات'));
    await tap(find.text('افزودن سند'));
    await name('نامه');
    await tap(find.text('نامه'));
    await tap(find.text('افزودن جزئیات سند'));
    await name('پیوست');
    await tap(find.byTooltip('گزینه‌های پیوست'));
    await tap(find.text('ویرایش نام'));
    await name('پیوست نامه');
    await tap(find.byTooltip('گزینه‌های پیوست نامه'));
    await tap(find.text('حذف ردیف'));
    await tap(find.text('حذف'));
    await tap(find.text('افزودن جزئیات سند'));
    await name('تاریخ نامه');
    expect(repo.writes, isEmpty);
    await tap(find.text('ذخیره کاتالوگ'));
    expect(repo.writes.single['endpoint'], 'save_catalog_layout');
    expect(repo.writes.single['version'], 'initial');
    await tap(find.text('مکاتبات'));
    await tap(find.text('نامه'));
    expect(find.text('تاریخ نامه'), findsOneWidget);
    expect(find.text('پیوست نامه'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('six matching office tiles stay visible with no personnel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        app(OfficeUsersPage(company: 'دفتر الف', repository: Repo())));
    await tester.pumpAndSettle();
    final tiles = ['', 'finance', 'hr', 'sales', 'operations', 'it']
        .map((group) => find.byKey(ValueKey('office-group:$group')));
    final sizes = tiles.map(tester.getSize).toSet();
    expect(sizes, hasLength(1));
    expect(find.text('۰ نفر'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile filter applies and clears in the bottom sheet',
      (tester) async {
    final repo = Repo()
      ..people = [
        {
          'name': 'EMP1',
          'employee_name': 'سارا احمدی',
          'department': 'مالی',
          'account_status': 'active',
          'profile': 'PROFILE',
          'user_id': 'sara@example.com'
        },
        {
          'name': 'EMP2',
          'employee_name': 'علی احمدی',
          'department': 'مالی',
          'account_status': 'no_account',
          'profile': null
        },
      ];
    await tester.pumpWidget(
        app(OfficeUsersPage(company: 'دفتر الف', repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فیلتر'));
    await tester.pumpAndSettle();
    expect(find.text('فیلتر پرسنل'), findsOneWidget);
    await tester.tap(find.text('همه پروفایل‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابدار').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعمال فیلتر'));
    await tester.pumpAndSettle();
    expect(find.text('سارا احمدی'), findsOneWidget);
    expect(find.text('علی احمدی'), findsNothing);
    await tester.tap(find.text('فیلتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاک‌کردن فیلتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعمال فیلتر'));
    await tester.pumpAndSettle();
    expect(find.text('علی احمدی'), findsOneWidget);
    expect(repo.writes, isEmpty);
  });

  testWidgets(
      'profile card menu confirms deletion and hides accountant shortcut',
      (tester) async {
    final repo = Repo();
    await tester.pumpWidget(
        app(AccessProfilesPage(company: 'دفتر الف', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('شروع با الگوی حسابدار'), findsNothing);
    await tester.tap(find.byTooltip('گزینه‌های پروفایل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف پروفایل'));
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(repo.writes.single, {
      'endpoint': 'delete_profile',
      'company': 'دفتر الف',
      'name': 'PROFILE',
      'modified': 'stamp',
    });
    expect(find.text('حسابدار'), findsNothing);
  });

  testWidgets('manual invitation displays the single-use code and copies it',
      (tester) async {
    final repo = Repo();
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(app(OfficeAccountCreate(
      company: 'دفتر الف',
      repository: repo,
      initialEmployee: 'EMP',
      people: const [
        {
          'name': 'EMP',
          'employee_name': 'سارا احمدی',
          'contact_methods': ['email']
        },
      ],
    )));
    final manual = find.text('دریافت کد دعوت دستی');
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ایجاد حساب کاربری'));
    await tester.pumpAndSettle();
    expect(repo.writes.single, {
      'endpoint': 'create_account',
      'employee': 'EMP',
      'company': 'دفتر الف',
      'method': 'email',
      'delivery': 'manual_code',
      'invite': 1,
    });
    expect(find.text('کد دعوت یک‌بارمصرف'), findsOneWidget);
    expect(find.text('H2K5D6F8G9'), findsOneWidget);
    await tester.tap(find.byTooltip('کپی کد'));
    await tester.pumpAndSettle();
    expect(copied, 'H2K5D6F8G9');
    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();
    expect(find.text('H2K5D6F8G9'), findsNothing);
  });

  testWidgets('only pending accounts offer a new manual invitation',
      (tester) async {
    final repo = Repo()..pending = true;
    Widget screen(Key key) => app(OfficeAccountDetails(
        key: key, company: 'دفتر الف', employee: 'EMP', repository: repo));
    await tester.pumpWidget(screen(const ValueKey('pending')));
    await tester.pumpAndSettle();
    expect(find.text('در انتظار فعال‌سازی'), findsOneWidget);
    await tester.tap(find.text('صدور مجدد کد دعوت دستی'));
    await tester.pumpAndSettle();
    expect(repo.writes.single['endpoint'], 'invite_account');
    expect(repo.writes.single['delivery'], 'manual_code');
    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();
    repo.pending = false;
    await tester.pumpWidget(screen(const ValueKey('active')));
    await tester.pumpAndSettle();
    expect(find.text('در انتظار فعال‌سازی'), findsNothing);
    expect(find.text('صدور مجدد کد دعوت دستی'), findsNothing);
    expect(find.text('تحویل دعوت‌نامه و فعال‌سازی'), findsNothing);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        'matrix supported unchecked differs from dash and collapse preserves grants $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final grants = <String, List<String>>{
        'Journal Entry': ['read']
      };
      await tester.pumpWidget(app(StatefulBuilder(
          builder: (_, update) => Scaffold(
                  body: ListView(children: [
                AccessPermissionMatrix(
                    catalog: catalog,
                    grants: grants,
                    onChanged: () => update(() {})),
              ])))));
      await expandMatrix(tester);
      expect(find.byKey(const ValueKey('grant:Journal Entry:delete')),
          findsOneWidget);
      expect(
          tester
              .widget<Checkbox>(
                  find.byKey(const ValueKey('grant:Journal Entry:delete')))
              .value,
          false);
      expect(find.byKey(const ValueKey('grant:Account:create')), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('grant:Journal Entry:write')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ثبت حسابداری'));
      await tester.pumpAndSettle();
      expect(grants['Journal Entry'], containsAll(['read', 'write']));
      expect(grants['Account'], isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'create existing employee account has no profile or office chooser $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = Repo();
      await tester.pumpWidget(app(OfficeAccountCreate(
          company: 'دفتر الف',
          repository: repo,
          people: const [
            {
              'name': 'EMP',
              'employee_name': 'سارا احمدی',
              'user_id': null,
              'contact_methods': ['mobile']
            },
          ])));
      expect(find.text('پروفایل دسترسی'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سارا احمدی').last);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('نام کاربری و رمز موقت به موبایل ثبت‌شده پیامک می‌شود.'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'ایجاد حساب کاربری'));
      await tester.pumpAndSettle();
      expect(repo.writes.single, {
        'endpoint': 'create_account',
        'method': 'mobile',
        'employee': 'EMP',
        'company': 'دفتر الف',
        'invite': 1,
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('profile name required save explicit and editor restores values',
      (tester) async {
    final repo = Repo();
    await tester.pumpWidget(
        app(AccessProfilesPage(company: 'دفتر الف', repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پروفایل جدید'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره پروفایل'));
    await tester.pumpAndSettle();
    expect(find.text('نام پروفایل را وارد کنید.'), findsOneWidget);
    expect(repo.writes, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'جدید');
    await tester.tap(find.text('ذخیره پروفایل'));
    await tester.pumpAndSettle();
    expect(repo.writes.single['title'], 'جدید');
    await tester.tap(find.text('حسابدار'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'حسابدار');
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'applying profile previews merged rights without saving automatically',
      (tester) async {
    final repo = Repo();
    await tester.pumpWidget(app(OfficeAccountDetails(
        company: 'دفتر الف', employee: 'EMP', repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دسترسی‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابدار').last);
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    await tester.ensureVisible(find.text('ذخیره دسترسی‌ها'));
    await tester.tap(find.text('ذخیره دسترسی‌ها'));
    await tester.pumpAndSettle();
    expect(repo.writes.single['profile'], 'PROFILE');
    expect(repo.writes.single['grants'], {
      'Account': ['read'],
      'Journal Entry': ['read', 'create']
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'accountant example is an unsaved editable preview not an assignment',
      (tester) async {
    final repo = Repo();
    await tester.pumpWidget(app(AccessProfileEditor(
        company: 'دفتر الف',
        repository: repo,
        catalog: catalog,
        example: const {
          'title': 'حسابدار',
          'description': 'بدون حذف',
          'grants': {
            'Journal Entry': ['read', 'create', 'write'],
            'Account': ['read']
          }
        })));
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'حسابدار');
    await expandMatrix(tester);
    expect(
        tester
            .widget<Checkbox>(
                find.byKey(const ValueKey('grant:Journal Entry:delete')))
            .value,
        false);
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
