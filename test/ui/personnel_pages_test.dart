import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements PersonnelRepository {}

void main() {
  setUpAll(() async {
    final font = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('personnel list and detail at $width', (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final rows = [
        for (final (i, name) in [
          'علی رضایی',
          'مریم کریمی',
          'محمد احمدی',
          'سمیرا حسینی',
          'رضا محمدی'
        ].indexed)
          <String, dynamic>{
            'id': 'person-$i',
            'employee_code': 'EMP-004${i + 2}',
            'display_name': name,
            'job_title': 'کارشناس منابع انسانی',
            'department': 'واحد منابع انسانی',
            'disabled': i == 4,
            'date_of_joining': '1402/04/21',
            'employment_type': 'تمام وقت'
          },
      ];
      when(() => repository.list('office'))
          .thenAnswer((_) async => {'can_edit': true, 'rows': rows});
      when(() => repository.detail('person-0')).thenAnswer((_) async => {
            'can_edit': true,
            'revision': '1',
            'profile': rows.first,
            'records': [
              {
                'name': 'r1',
                'kind': 'attendance',
                'title': 'ثبت حضور',
                'record_date': '1403/03/15'
              },
              {
                'name': 'r2',
                'kind': 'document',
                'title': 'آپلود قرارداد',
                'record_date': '1403/03/14'
              },
              {
                'name': 'r3',
                'kind': 'evaluation',
                'title': 'ارزیابی عملکرد',
                'record_date': '1403/03/13'
              },
            ],
          });
      await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: PersonnelPage(company: 'office', repository: repository)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await expectLater(find.byType(Scaffold),
            matchesGoldenFile('goldens/personnel_list_390.png'));
      }
      await tester.tap(find.text('علی رضایی'));
      await tester.pumpAndSettle();
      expect(find.text('پرونده پرسنلی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await expectLater(find.byType(Scaffold).last,
            matchesGoldenFile('goldens/personnel_detail_390.png'));
      }
      await tester.tap(find.text('مدارک'));
      await tester.pumpAndSettle();
      expect(find.text('مدارک و مستندات'), findsOneWidget);
      await tester.tap(find.text('مدارک و مستندات'));
      await tester.pumpAndSettle();
      expect(find.text('آپلود قرارداد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, tags: 'golden');
  }
}
