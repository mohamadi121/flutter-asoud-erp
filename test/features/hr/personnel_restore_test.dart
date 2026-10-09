import 'dart:io';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/hr/domain/hr_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_models.dart';
import 'package:asoud_erp/features/hr/presentation/pages/hr_home_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Mock implements FrappeClient {}

class _Hr extends Fake implements HrRepository {
  @override
  Future<HrDashboard> dashboard(String company) async => const HrDashboard(
      employee: HrEmployee(
          id: 'EMP-42',
          name: 'سارا کریمی',
          company: 'office',
          partyProfile: 'PARTY-1'));
}

class _People extends Fake implements PersonnelRepository {
  @override
  void dispose() {}
  bool failed = true;
  int retries = 0;
  String? imported;
  final profile = <String, dynamic>{
    'id': 'PARTY-1',
    'display_name': 'سارا کریمی',
    'job_title': 'کارشناس فروش',
    'department': 'فروش',
    'employment_type': 'تمام وقت',
    'employee_code': 'EMP-42',
    'date_of_joining': '1403/01/01',
  };
  @override
  Future<Map<String, dynamic>> list(String company) async => {
        'rows': [profile],
        'can_edit': true,
      };
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'profile': profile,
        'records': <Map<String, dynamic>>[],
        'revision': 'revision-7',
        'can_edit': true,
        'offline': true,
        'pending_sync': true,
        'sync_failed': failed,
      };
  @override
  Future<void> retryFailed(String id) async {
    expect(id, 'PARTY-1');
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
}

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

Future<void> _tap(WidgetTester tester, String label,
    {bool settle = true}) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(target, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('HR home my profile pushes the historical detail directly',
      (tester) async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenReturn('https://erp.example');
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'hr', fullName: 'سارا کریمی', roles: ['HR Manager']));
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => {
              'message': {'data': await _People().detail('PARTY-1')}
            });
    final observer = _Pushes();
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<HrRepository>.value(value: _Hr()),
          RepositoryProvider<FrappeApiClient>.value(value: client),
        ],
        child: MaterialApp(
            navigatorObservers: [observer],
            home: const HrHomePage(company: 'office'))));
    await tester.pumpAndSettle();
    observer.routes.clear();
    await _tap(tester, 'پروفایل من');
    expect(observer.routes, hasLength(1));
    expect(find.byType(PersonnelDetailPage), findsOneWidget);
    expect(
        tester.widget<PersonnelDetailPage>(find.byType(PersonnelDetailPage)).id,
        'PARTY-1');
    expect(find.byType(HrProfilePage), findsNothing);
  });

  testWidgets(
      'list account menu keeps its shared actions and unavailable notice',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PersonnelPage(company: 'office', repository: _People())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('مدیریت دسترسی'));
    await tester.pumpAndSettle();
    for (final label in [
      'مدیریت دسترسی',
      'ایجاد/تغییر حساب کاربری',
      'ارسال مجدد دعوت',
      'مشاهده سوابق ورود'
    ]) {
      expect(find.widgetWithText(PopupMenuItem<String>, label), findsOneWidget);
    }
    expect(find.text('حذف حساب کاربری'), findsNothing);
    await tester.tap(find.text('مشاهده سوابق ورود'));
    await tester.pumpAndSettle();
    expect(
        find.text('این قابلیت هنوز به سرویس متصل نشده است.'), findsOneWidget);
  });

  test('only the historical personnel detail page exists', () {
    final directory = Directory('lib/features/hr/presentation/pages');
    expect(File('${directory.path}/personnel_file_page.dart').existsSync(),
        isFalse);
    expect(File('${directory.path}/personnel_file_sections.dart').existsSync(),
        isFalse);
    final source = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(RegExp(r'class PersonnelDetailPage\b').allMatches(source),
        hasLength(1));
    expect(source.contains('PersonnelFilePage'), isFalse);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('real list row pushes exactly one detail route at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final people = _People()..failed = false;
      final observer = _Pushes();
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          navigatorObservers: [observer],
          home: PersonnelPage(company: 'office', repository: people)));
      await tester.pumpAndSettle();
      observer.routes.clear();
      await _tap(tester, 'سارا کریمی');
      expect(observer.routes, hasLength(1));
      expect(find.byType(PersonnelDetailPage), findsOneWidget);
      expect(
          tester
              .widget<PersonnelDetailPage>(find.byType(PersonnelDetailPage))
              .id,
          'PARTY-1');
      expect(find.text('پرونده پرسنلی'), findsOneWidget);
      expect(find.text('EMP-42'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['سوابق', 'مدارک', 'نمای کلی']) {
        await _tap(tester, label);
        expect(observer.routes, hasLength(1));
        expect(tester.takeException(), isNull);
      }
      await _tap(tester, 'اطلاعات پرسنلی');
      expect(find.text('اطلاعات استخدامی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PersonnelDetailPage), findsNothing);
      expect(find.byType(PersonnelPage), findsOneWidget);
    });
  }

  testWidgets('sync notice retries failed sends and refreshes state',
      (tester) async {
    final people = _People();
    await tester.pumpWidget(MaterialApp(
        home: PersonnelDetailPage(id: 'PARTY-1', repository: people)));
    await tester.pumpAndSettle();
    expect(find.text('همگام‌سازی نیازمند بررسی است'), findsOneWidget);
    await _tap(tester, 'تلاش مجدد برای همگام‌سازی');
    expect(people.retries, 1);
    expect(find.text('ذخیره روی گوشی؛ در انتظار همگام‌سازی'), findsOneWidget);
    expect(find.text('تلاش مجدد برای همگام‌سازی'), findsNothing);
  });

  testWidgets('local records import requires source and confirmation',
      (tester) async {
    final people = _People();
    await tester.pumpWidget(MaterialApp(
        home: PersonnelDetailPage(id: 'PARTY-1', repository: people)));
    await tester.pumpAndSettle();
    await _tap(tester, 'انتقال سوابق پرسنل محلی', settle: false);
    expect(people.imported, isNull);
    await tester.tap(find.text('پرونده محلی'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تأیید اتصال پرونده‌ها'), findsOneWidget);
    expect(people.imported, isNull);
    await tester.tap(find.text('تأیید انتقال'));
    await tester.pumpAndSettle();
    expect(people.imported, 'LOCAL-source->PARTY-1');
    expect(find.text('انتقال ثبت شد؛ وضعیت ارسال در پرونده نمایش داده می‌شود.'),
        findsOneWidget);
  });
}
