import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/employee/presentation/pages/my_info_page.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _WorkflowRepository implements WorkflowRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async =>
      [for (var i = 1; i <= 8; i++) _draft(i)];
}

WorkflowDefinition _draft(int i) => WorkflowDefinition(
      id: 'WF-000$i',
      code: 'WF-000$i',
      title: i.isEven ? 'درخواست مرخصی $i' : 'فرایند خرید کالا $i',
      targetDoctype: i.isEven ? 'Leave Application' : 'Material Request',
      status: WorkflowDefinitionStatus.active,
      isLocked: i == 7,
      version: 1,
      stepsCount: 4,
      modified: null,
      iconKey: i.isEven ? 'leave' : 'purchase',
    );

class _PersonnelRepository extends Mock implements PersonnelRepository {}

class _Files extends Fake implements PersonnelFileRepository {
  @override
  Future<PersonnelFile> myFile() async => PersonnelFile.fromJson(const {
        'header': {
          'name': 'امیر موفق',
          'employee_code': 'EMP-42',
          'designation': 'کارشناس',
          'department_name': 'فروش',
          'status': 'Active'
        },
        'personal': {
          'national_id': '0012345678',
          'birth_date': '1990-03-21',
          'marital_status': 'Married',
          'mobile': '09123456789',
          'email': 'amir@example.com',
          'address_line': 'تهران، خیابان آزادی'
        },
        'organization': {
          'department_name': 'فروش',
          'designation': 'کارشناس',
          'reports_to': {'name': 'سارا احمدی'},
          'branch': 'تهران'
        },
        'employment': {
          'employment_type': 'Full-time',
          'date_of_joining': '2025-03-21',
          'service_length': {'years': 1, 'months': 6}
        },
        'contracts': [
          {
            'state': 'active',
            'start_date': '2026-03-21',
            'end_date': '2027-03-20',
            'days_remaining': 166
          }
        ]
      });
}

Finder _paddedList({double min = 88}) => find.byWidgetPredicate((w) =>
    w is ListView &&
    w.padding is EdgeInsets &&
    (w.padding as EdgeInsets).bottom >= min);

ScrollableState _scrollState(WidgetTester tester, Finder of) =>
    tester.state<ScrollableState>(
        find.descendant(of: of, matching: find.byType(Scrollable)));

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('workflow list reserves room for the bottom bar at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<WorkflowRepository>.value(
          value: _WorkflowRepository(),
          child: const MaterialApp(
              home: Directionality(
            textDirection: TextDirection.rtl,
            child: WorkflowListPage(),
          )),
        ),
      );
      await tester.pumpAndSettle();

      final list = _paddedList();
      expect(list, findsOneWidget);
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(_scrollState(tester, list).position.pixels,
          _scrollState(tester, list).position.maxScrollExtent);

      final lastCard = tester.getRect(find
          .descendant(of: find.byType(Card).last, matching: find.byType(InkWell))
          .first);
      final createButton = tester.getRect(find.byType(FilledButton));
      expect(lastCard.bottom, lessThan(createButton.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('personnel detail leaves space below the list at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PersonnelRepository();
      when(() => repository.detail('person-0')).thenAnswer((_) async => {
            'can_edit': true,
            'revision': '1',
            'profile': {
              'id': 'person-0',
              'employee_code': 'EMP-42',
              'display_name': 'علی رضایی',
              'job_title': 'کارشناس منابع انسانی',
              'department': 'واحد منابع انسانی',
              'disabled': false,
              'date_of_joining': '1402/04/21',
              'employment_type': 'تمام وقت'
            },
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
            ],
          });
      await tester.pumpWidget(MaterialApp(
          home: Directionality(
        textDirection: TextDirection.rtl,
        child: PersonnelDetailPage(id: 'person-0', repository: repository),
      )));
      await tester.pumpAndSettle();

      final list = _paddedList();
      expect(list, findsOneWidget);
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(_scrollState(tester, list).position.pixels,
          _scrollState(tester, list).position.maxScrollExtent);
      expect(find.text('پرونده پرسنلی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('my profile leaves space below the scroll view at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(MaterialApp(home: MyInfoPage(repository: _Files())));
      await tester.pumpAndSettle();

      expect(
          find.byWidgetPredicate((w) =>
              w is SingleChildScrollView &&
              w.padding is EdgeInsets &&
              (w.padding as EdgeInsets).bottom >= 88),
          findsOneWidget);
      expect(find.text('اطلاعات من'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finance settings reserves room for the bottom bar at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
          home: Directionality(
        textDirection: TextDirection.rtl,
        child: AccountingPreferencesPage(
            officeName: 'شرکت نمونه', offlinePreview: true),
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      final list = _paddedList(min: 96);
      expect(list, findsOneWidget);
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(_scrollState(tester, list).position.pixels,
          _scrollState(tester, list).position.maxScrollExtent);
      expect(find.text('ذخیره و ادامه'), findsOneWidget);
    });
  }
}