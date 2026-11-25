import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/roles/data/access_management_repository.dart';
import 'package:asoud_erp/features/roles/presentation/access_profiles_page.dart';
import 'package:asoud_erp/features/roles/presentation/office_users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const catalog = <AccessMap>[
  {'module': 'مالی', 'group': 'ثبت حسابداری', 'doctype': 'Journal Entry',
    'title': 'سند حسابداری', 'actions': ['read', 'create', 'write', 'delete'], 'details': []},
  {'module': 'مالی', 'group': 'ثبت حسابداری', 'doctype': 'Account',
    'title': 'کدینگ', 'actions': ['read'], 'details': []},
];

class Client extends Fake implements FrappeApiClient {}
class Repo extends AccessManagementRepository {
  Repo() : super(Client());
  final writes = <Map<String, dynamic>>[];
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    if (method == 'list_profiles') { return {'catalog': catalog, 'profiles': [
      {'name': 'PROFILE', 'title': 'حسابدار', 'description': '', 'company': 'دفتر الف',
        'readonly': false, 'modified': 'stamp', 'grants': {'Journal Entry': ['read', 'create']}},
    ]}; }
    if (method == 'get_account') { return {'employee': 'EMP', 'title': 'سارا احمدی',
      'designation': 'کارشناس اداری', 'company': 'دفتر الف', 'user': 'sara@example.com',
      'legacy': false, 'profile': null, 'token': 'stamp', 'catalog': catalog,
      'grants': {'Account': ['read']}}; }
    writes.add({'endpoint': method, ...args});
    return {};
  }
}

Widget app(Widget child) => MaterialApp(theme: AsoudTheme.light,
  builder: (_, c) => Directionality(textDirection: TextDirection.rtl, child: c!), home: child);

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
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('matrix supported unchecked differs from dash and collapse preserves grants $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final grants = <String, List<String>>{'Journal Entry': ['read']};
      await tester.pumpWidget(app(StatefulBuilder(builder: (_, update) => Scaffold(body: ListView(children: [
        AccessPermissionMatrix(catalog: catalog, grants: grants, onChanged: () => update(() {})),
      ])))));
      await expandMatrix(tester);
      expect(find.byKey(const ValueKey('grant:Journal Entry:delete')), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('grant:Journal Entry:delete'))).value, false);
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

    testWidgets('create existing employee account has no profile or office chooser $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = Repo();
      await tester.pumpWidget(app(OfficeAccountCreate(company: 'دفتر الف', repository: repo, people: const [
        {'name': 'EMP', 'employee_name': 'سارا احمدی', 'user_id': null,
          'contact_methods': ['mobile']},
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
        'endpoint': 'create_account', 'method': 'mobile', 'employee': 'EMP',
        'company': 'دفتر الف', 'invite': 1,
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('profile name required save explicit and editor restores values', (tester) async {
    final repo = Repo();
    await tester.pumpWidget(app(AccessProfilesPage(company: 'دفتر الف', repository: repo)));
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
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'حسابدار');
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applying profile previews merged rights without saving automatically', (tester) async {
    final repo = Repo();
    await tester.pumpWidget(app(OfficeAccountDetails(company: 'دفتر الف', employee: 'EMP', repository: repo)));
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
    expect(repo.writes.single['grants'], {'Account': ['read'], 'Journal Entry': ['read', 'create']});
    expect(tester.takeException(), isNull);
  });

  testWidgets('accountant example is an unsaved editable preview not an assignment', (tester) async {
    final repo = Repo();
    await tester.pumpWidget(app(AccessProfileEditor(company: 'دفتر الف', repository: repo, catalog: catalog,
      example: const {'title': 'حسابدار', 'description': 'بدون حذف',
        'grants': {'Journal Entry': ['read', 'create', 'write'], 'Account': ['read']}})));
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'حسابدار');
    await expandMatrix(tester);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('grant:Journal Entry:delete'))).value, false);
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
