import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/app_fields.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The shared field look (AppTextField/AppSelectField) replaces the old
/// AsoudFormField/AsoudFormDropdown in the personnel record form without
/// changing validation rules, the payload or the required marks.
class _Repository extends Mock implements PersonnelRepository {
  @override
  bool get localDemo => false;
  @override
  Future<Map<String, dynamic>> recordOptions(String id) async => {
        'appraisal_cycles': [
          {'name': 'دوره سالانه'},
          {'name': 'دوره ۴ ماهه'}
        ]
      };
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
        'profile': {'id': id, 'display_name': 'علی رضایی'},
        'revision': 'profile-1',
        'can_edit': true,
        'records': []
      };
  final values = <String, Map<String, dynamic>>{};
  int creates = 0;
  @override
  Future<void> add(
      String id, Map<String, dynamic> payload, String requestId) async {
    creates++;
    values['new'] = {...payload, '_revision': '1', '_can_edit': true};
  }

  @override
  Future<Map<String, dynamic>> record(String id) async =>
      Map.from(values[id]!);
}

Future<void> _openRecord(WidgetTester tester, _Repository repo,
    {required String kind, required String entry}) async {
  await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      home: PersonnelDetailPage(id: 'P-1', repository: repo)));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(kind).last);
  await tester.tap(find.text(kind).last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(entry).last);
  await tester.tap(find.text(entry).last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('ثبت مورد جدید').last);
  await tester.tap(find.text('ثبت مورد جدید'));
  await tester.pumpAndSettle();
}

Future<void> _section(WidgetTester tester, String title) async {
  final header = find.descendant(
      of: find.byType(ExpansionTile), matching: find.text(title));
  await tester.scrollUntilVisible(header, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'attendance record form uses the shared text fields with required marks and its validation message',
      (tester) async {
    final repo = _Repository();
    await _openRecord(tester, repo, kind: 'سوابق', entry: 'کارکرد و سوابق حضور');
    await _section(tester, 'اطلاعات اصلی');
    expect(find.byType(AppTextField), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'عنوان *'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'تاریخ *'), findsOneWidget);
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(find.text('عنوان بین ۱ تا ۱۴۰ نویسه وارد کنید.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان *'), 'حضور روزانه');
    tester
        .widget<AsoudFormDateField>(find.byType(AsoudFormDateField).first)
        .controller
        .text = '2026-10-05';
    await _section(tester, 'ساعات حضور');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ساعت ورود'), '08:00');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ساعت خروج'), '16:00');
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(repo.values['new']!['title'], 'حضور روزانه');
    expect(repo.values['new']!['start'], '08:00');
  });

  testWidgets(
      'evaluation record form picks the appraisal cycle from the shared sheet and keeps the payload',
      (tester) async {
    final repo = _Repository();
    await _openRecord(tester, repo, kind: 'سوابق', entry: 'ارزیابی عملکرد');
    await _section(tester, 'اطلاعات اصلی');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان *'), 'ارزیابی دوره');
    tester
        .widget<AsoudFormDateField>(find.byType(AsoudFormDateField).first)
        .controller
        .text = '2026-10-06';
    await _section(tester, 'نتیجه ارزیابی');
    expect(find.widgetWithText(TextFormField, 'امتیاز هدف از ۱۰۰ *'),
        findsOneWidget);
    final cycle = find.ancestor(of: find.text('دوره ارزیابی *'),
        matching: find.byType(AppSelectField));
    await tester.ensureVisible(cycle);
    await tester.pumpAndSettle();
    expect(cycle.hitTestable(), findsOneWidget);
    await tester.tap(cycle);
    await tester.pumpAndSettle();
    expect(find.byType(AppSelectField), findsOneWidget);
    await tester.ensureVisible(find.text('دوره ۴ ماهه').last);
    await tester.tap(find.text('دوره ۴ ماهه').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'امتیاز هدف از ۱۰۰ *'), '85');
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(repo.values['new']!['appraisal_cycle'], 'دوره ۴ ماهه');
    expect(repo.values['new']!['score'], 85);
  });
}
