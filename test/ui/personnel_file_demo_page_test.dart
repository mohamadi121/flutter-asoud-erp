import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/demo/hr_demo_data.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeClient {}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _pop(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void _filled(WidgetTester tester, String screen) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan!.toPlainText())
      .toList();
  expect(texts.where((text) => text.trim().isEmpty), isEmpty, reason: screen);
  expect(texts.where((text) => text == 'ثبت نشده'), isEmpty, reason: screen);
  expect(texts.where((text) => text.trim() == '—'), isEmpty, reason: screen);
  expect(find.text('—'), findsNothing, reason: screen);
  expect(find.text('ثبت نشده'), findsNothing, reason: screen);
  expect(find.text('null'), findsNothing, reason: screen);
  expect(find.textContaining('نمونه'), findsNothing,
      reason: 'پیش‌نمایش نباید خود را نمونه معرفی کند');
  expect(tester.takeException(), isNull, reason: screen);
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'all 12 demo people open the restored detail with filled data at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Client();
      when(() => client.isAuthenticated).thenReturn(false);
      when(() => client.serverIdentity).thenReturn('https://preview.example');
      when(() => client.authenticationChanges)
          .thenAnswer((_) => const Stream<bool>.empty());
      final clock = HrDemoData.at(DateTime(2026, 10, 5));
      final personnel = PersonnelRepository(client,
          local: FakeLocalRecordStore(), demoData: clock);
      final rows = (await personnel.list(hrDemoCompany))['rows'] as List;
      expect(rows, hasLength(hrDemoEmployeeCodes.length));
      expect(rows.cast<Map>().where((row) => row['is_sample'] == true),
          hasLength(12));
      for (final code in hrDemoEmployeeCodes) {
        final detail = await personnel.detail(code);
        final profile = detail['profile'] as Map;
        final records = (detail['records'] as List).cast<Map>();
        await tester.pumpWidget(MaterialApp(
            theme: AsoudTheme.light,
            home: PersonnelPage(
                key: ValueKey(code),
                company: hrDemoCompany,
                repository: personnel)));
        await tester.pumpAndSettle();
        await _tap(tester, profile['display_name'] as String);
        expect(find.byType(PersonnelDetailPage), findsOneWidget);
        expect(
            tester
                .widget<PersonnelDetailPage>(find.byType(PersonnelDetailPage))
                .id,
            code);
        expect(find.text(code), findsOneWidget);
        expect(find.text(profile['display_name'] as String), findsNWidgets(2));
        expect(find.text(profile['department'] as String), findsNWidgets(3));
        expect(find.byType(Image), findsOneWidget);
        _filled(tester, '$code overview');
        await _tap(tester, 'اطلاعات پرسنلی');
        _filled(tester, '$code sections');
        await _tap(tester, 'اطلاعات فردی');
        expect(find.text(profile['national_id'] as String), findsOneWidget);
        expect(find.text(profile['mobile'] as String), findsOneWidget);
        expect(find.text(profile['father_name'] as String), findsOneWidget);
        expect(find.text(profile['company_email'] as String), findsOneWidget);
        expect(find.text(profile['emergency_contact_name'] as String),
            findsOneWidget);
        _filled(tester, '$code personal');
        await _pop(tester);
        await _tap(tester, 'اطلاعات سازمانی');
        expect(find.text(profile['job_title'] as String), findsNWidgets(2));
        expect(find.text(profile['department'] as String), findsNWidgets(3));
        _filled(tester, '$code organization');
        await _pop(tester);
        await _tap(tester, 'اطلاعات استخدامی');
        expect(find.text(code), findsNWidgets(2));
        expect(find.text(profile['date_of_joining'] as String), findsOneWidget);
        _filled(tester, '$code employment');
        await _pop(tester);
        await _tap(tester, 'قراردادها');
        final documents =
            records.where((record) => record['kind'] == 'document').toList();
        expect(documents, isNotEmpty);
        expect(find.text(documents.first['title'] as String), findsNWidgets(2));
        _filled(tester, '$code contract documents');
        await _pop(tester);
        await _pop(tester);
        await _tap(tester, 'مدارک');
        await _tap(tester, 'مدارک و مستندات');
        for (final document in documents) {
          await _tap(tester, document['title'] as String);
          expect(find.text('جزئیات سابقه'), findsOneWidget);
          expect(find.text(document['title'] as String), findsOneWidget);
          expect(find.text('ویرایش سابقه'), findsNothing);
          final attachment = await personnel.record(document['name'] as String);
          expect(attachment['file'], isNotEmpty);
          expect(find.text(attachment['date'] as String), findsOneWidget);
          expect(find.text('—'), findsNothing);
          await _pop(tester);
        }
        await _pop(tester);
        await _tap(tester, 'سوابق');
        await _tap(tester, 'تاریخچه');
        for (final record
            in records.where((record) => record['kind'] == 'history')) {
          expect(find.text(record['title'] as String), findsOneWidget);
        }
        _filled(tester, '$code history');
        await _pop(tester);
        await _pop(tester);
      }
    });
  }

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
