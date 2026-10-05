import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/demo/hr_demo_data.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeClient {}

final _tabs = {
  'نمای کلی': 'overview',
  'اطلاعات پرسنلی': 'sections',
  'مدارک': 'documents',
  'سوابق': 'history',
};

final _sections = {
  'اطلاعات فردی': 'personal',
  'اطلاعات سازمانی': 'organisation',
  'اطلاعات استخدامی': 'employment',
  'قراردادها': 'contracts',
  'حقوق و مزایا': 'salary',
  'حضور و غیاب': 'attendance',
};

final _verticalScrollable = find.byWidgetPredicate((widget) =>
    widget is Scrollable && widget.axisDirection == AxisDirection.down);

Future<void> _revealAndTap(WidgetTester tester, Finder finder) async {
  var guard = 0;
  while (finder.evaluate().isEmpty && guard++ < 12) {
    await tester.drag(_verticalScrollable.first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder.evaluate(), isNotEmpty,
      reason: 'بخش موردنظر پیدا نشد؛ ساختار صفحه تغییر کرده است.');
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _pop(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

/// The only empty values the backend legitimately sends: a serving employee has
/// no relieving date, and documents without an expiry date show one.
const _allowedEmpties = {
  'employment': {'—'},
  'documents': {'انقضا: —'},
};

void main() {
  testWidgets('the seeded demo file shows no empty placeholders anywhere',
      (tester) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.serverIdentity).thenReturn('https://preview.example');
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    final store = FakeLocalRecordStore();
    final clock = HrDemoData.at(DateTime(2026, 10, 5));
    final personnel =
        PersonnelRepository(client, local: store, demoData: clock);
    final files =
        PersonnelFileRepository(client, store: store, demoData: clock);

    final rows = (await personnel.list(hrDemoCompany))['rows'] as List;
    expect(rows, hasLength(hrDemoEmployeeCodes.length));
    expect(
        rows.cast<Map<String, dynamic>>().where((r) => r['is_sample'] == true),
        hasLength(12));

    // A department manager sees salary, plain staff and the employee themself
    // do not.
    for (final subject in const ['EMP-0003', 'EMP-0006']) {
      for (final mine in [
        false,
        ...(subject == hrDemoSelfEmployeeCode ? [true] : [])
      ]) {
        final screens = <String, List<String>>{};
        void collect(String screen) =>
            screens.putIfAbsent(screen, () => []).addAll(tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data ?? ''));

        await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: mine
                ? PersonnelFilePage.mine(
                    key: ValueKey('$subject-$mine'),
                    repository: files,
                    personnel: personnel,
                  )
                : PersonnelFilePage(
                    key: ValueKey('$subject-$mine'),
                    profileId: subject,
                    repository: files,
                    personnel: personnel,
                  ),
          ),
        ));
        await tester.pumpAndSettle();
        collect('overview');
        expect(find.textContaining('نمونه'), findsNothing,
            reason: 'پیش‌نمایش نباید خود را نمونه معرفی کند');

        for (final tab in _tabs.entries) {
          await tester.tap(find.widgetWithText(Tab, tab.key));
          await tester.pumpAndSettle();
          collect(tab.value);
          if (tab.key == 'اطلاعات پرسنلی') {
            for (final entry in _sections.keys) {
              final finder = find.widgetWithText(InkWell, entry);
              if (finder.evaluate().isEmpty) {
                expect(entry, 'حقوق و مزایا',
                    reason: 'تنها بخش مجاز برای حذف، حقوق و مزایا است');
                continue;
              }
              await _revealAndTap(tester, finder);
              collect(_sections[entry]!);
              await _pop(tester);
            }
          }
          if (tab.key == 'مدارک') {
            // Opening a document pulls its attachment through the personnel
            // repository, which must answer for sample records too.
            await _revealAndTap(tester, find.byType(Card));
            collect('document');
            await _pop(tester);
          }
        }

        for (final entry in screens.entries) {
          expect(entry.value.where((text) => text.trim().isEmpty), isEmpty,
              reason: 'متن خالی در «${entry.key}»');
          expect(entry.value.where((text) => text == 'ثبت نشده'), isEmpty,
              reason: 'placeholder «ثبت نشده» در «${entry.key}»');
          for (final text in entry.value) {
            expect(
                text.trim() != '—' ||
                    (_allowedEmpties[entry.key]?.contains(text) ?? false),
                isTrue,
                reason: 'مقدار خالی «$text» در «${entry.key}»');
          }
        }
        // Real content, not an empty shell: every screen must repeat what the
        // payload actually carries.
        final file = PersonnelFile.fromJson(mine
            ? clock.file(hrDemoSelfEmployeeCode, selfView: true)
            : clock.file(subject));
        bool shows(String screen, String needle) =>
            screens[screen]!.any((text) => text.contains(needle));
        expect(shows('overview', file.header.name), isTrue);
        expect(shows('overview', file.header.employeeCode!), isTrue);
        expect(shows('overview', file.header.departmentName), isTrue);
        expect(shows('overview', 'وضعیت مدارک'), isTrue);
        expect(shows('overview', 'قرارداد فعلی'), isTrue);
        expect(shows('overview', 'روز مانده'), isTrue);
        expect(shows('personal', file.personal.nationalId), isTrue);
        expect(shows('personal', file.personal.mobile), isTrue);
        expect(
            shows('organisation', file.organization.reportsTo!.name), isTrue);
        expect(
            shows('employment', file.employment.serviceLength!.label), isTrue);
        expect(shows('contracts', file.contracts.first.terms), isTrue);
        expect(shows('attendance', 'مانده مرخصی'), isTrue);
        expect(
            shows(
                'attendance',
                toPersianDigits(
                    file.leave.first.remainingLeaves.toStringAsFixed(0))),
            isTrue,
            reason: 'مانده مرخصی باید فارسی و پر باشد');
        expect(shows('documents', 'در انتظار تأیید'), isTrue,
            reason: 'مدرک در انتظار تأیید باید برچسب فارسی داشته باشد');
        expect(
            screens['documents']!.any((text) => text == 'رو به انقضا'), isTrue,
            reason: 'هشدار انقضا باید در فهرست مدارک دیده شود');
        expect(shows('document', file.documents.first.title), isTrue);
        expect(shows('history', file.history.first.title), isTrue);
        final salary = screens.containsKey('salary');
        expect(salary, isTrue,
            reason: 'همه پرونده‌ها بخش حقوق را دارند؛ محتوایش محدود است');
        if (mine || subject != 'EMP-0003') {
          // The section exists for everyone but must stay empty for anyone who
          // may not see pay data.
          expect(screens['salary']!.any((text) => text.contains('حقوق پایه')),
              isFalse,
              reason: 'کارمنل غیرمدیر نباید عدد حقوق ببیند');
          expect(screens['salary']!.any((text) => text.contains('خلاصه فیش')),
              isFalse,
              reason: 'کارمنل غیرمدیر نباید فیش حقوقی ببیند');
        } else {
          expect(shows('salary', 'حقوق فعلی'), isTrue);
          expect(shows('salary', 'آخرین فیش حقوقی'), isTrue);
          expect(shows('salary', file.salary.current!.salaryStructure), isTrue);
          expect(shows('salary', 'حقوق پایه'), isTrue);
          expect(shows('salary', 'خلاصه فیش'), isTrue);
          expect(shows('salary', 'مزایا'), isTrue);
          expect(shows('salary', 'کسورات'), isTrue);
        }
      }
    }
  });

  testWidgets('a signed-in session never shows sample people', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.serverIdentity).thenReturn('https://erp.example');
    when(() => client.authenticationChanges)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
            userId: 'hr@example.com', fullName: 'HR', roles: ['HR Manager']));
    when(() => client.callMethod(any(), data: any(named: 'data')))
        .thenAnswer((call) async {
      if ((call.positionalArguments.first as String)
          .endsWith('list_personnel')) {
        return {
          'message': {
            'data': {
              'rows': [
                {'id': 'EMP-9001', 'display_name': 'کارمند واقعی'},
              ],
              'can_edit': true,
            }
          }
        };
      }
      return {
        'message': {
          'data': {
            'profile_id': 'EMP-9001',
            'profile': {'id': 'EMP-9001', 'display_name': 'کارمند واقعی'},
          }
        }
      };
    });
    final store = FakeLocalRecordStore();
    final personnel = PersonnelRepository(client,
        local: store, demoData: HrDemoData.at(DateTime(2026, 10, 5)));
    final files = PersonnelFileRepository(client,
        store: store, demoData: HrDemoData.at(DateTime(2026, 10, 5)));

    final result = await personnel.list(hrDemoCompany);
    final rows = (result['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'EMP-9001');
    expect(() => files.myHome(), throwsA(anything));
  });
}
