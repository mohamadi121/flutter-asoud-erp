import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/workflow_graph_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeApiClient {}

class _MockOfficeRepo implements OfficeRepository {
  @override
  Future<Office?> getDefaultOffice() async => Office(
        name: 'شرکت نمونه آسود',
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2026),
        setupComplete: true,
      );

  @override
  Future<Office> createOffice(Office office) => throw UnimplementedError();

  @override
  Future<List<Office>> listOffices() async => [];

  @override
  Future<Office> setDefaultOffice(Office office) => throw UnimplementedError();

  @override
  Future<Office> updateOffice(String id, Office office) =>
      throw UnimplementedError();
}

void main() {
  group('T2 regressions', () {
    test(
        'persianRoleLabel and formatUserGreetingRoles map roles and hide internal ids',
        () {
      expect(persianRoleLabel('Academics User'), 'کاربر آموزش');
      expect(persianRoleLabel('Agriculture User'), 'کارشناس کشاورزی');
      expect(persianRoleLabel('Dashboard Manager'), 'مدیر داشبورد');
      expect(persianRoleLabel('Delivery Manager'), 'مدیر تحویل');
      expect(persianRoleLabel('Delivery User'), 'کارشناس تحویل');
      expect(persianRoleLabel('Fulfillment User'), 'کارشناس پردازش سفارش');
      expect(persianRoleLabel('Inbox User'), 'کاربر صندوق پیام');
      expect(persianRoleLabel('Interviewer'), 'مصاحبه‌کننده');
      expect(persianRoleLabel('Knowledge Base Editor'), 'ویرایشگر پایگاه دانش');
      expect(persianRoleLabel('Purchase Master Manager'),
          'مدیر اطلاعات پایه خرید');

      final mixedRoles = [
        'Administrator',
        'ASOUD-ACCESS-USER-12345',
        'Academics User',
        'Delivery Manager',
      ];
      final greeting = formatUserGreetingRoles(mixedRoles);
      expect(greeting, contains('مدیر سامانه'));
      expect(greeting, contains('کاربر آموزش'));
      expect(greeting, contains('مدیر تحویل'));
      expect(greeting, isNot(contains('ASOUD-ACCESS-USER-')));
      expect(greeting, isNot(contains('Academics User')));
    });

    testWidgets(
        'Basic setup page tiles for treasury and inventory show به‌زودی',
        (tester) async {
      await tester.pumpWidget(
        RepositoryProvider<OfficeRepository>.value(
          value: _MockOfficeRepo(),
          child: const MaterialApp(
            locale: Locale('fa'),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: BaseAccountingSetupPage(officeName: 'شرکت نمونه آسود'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap «مالی و خزانه»
      final treasuryTile = find.text('مالی و خزانه');
      expect(treasuryTile, findsOneWidget);
      await tester.ensureVisible(treasuryTile);
      await tester.pumpAndSettle();
      await tester.tap(treasuryTile);
      await tester.pumpAndSettle();

      expect(find.text('به‌زودی'), findsOneWidget);
      expect(find.widgetWithText(AsoudHeader, 'مالی و خزانه'), findsOneWidget);

      // Go back
      Navigator.of(tester.element(find.text('به‌زودی'))).pop();
      await tester.pumpAndSettle();

      // Tap «انبار و کالا»
      final inventoryTile = find.text('انبار و کالا');
      expect(inventoryTile, findsOneWidget);
      await tester.ensureVisible(inventoryTile);
      await tester.pumpAndSettle();
      await tester.tap(inventoryTile);
      await tester.pumpAndSettle();

      expect(find.text('به‌زودی'), findsOneWidget);
      expect(find.widgetWithText(AsoudHeader, 'انبار و کالا'), findsOneWidget);
    });

    testWidgets(
        'Workflow graph canvas renders Persian ادامه ← for Continue transition label',
        (tester) async {
      final design = WorkflowDesign(
        workflow: const WorkflowDefinition(
          id: 'WF-1',
          code: 'WF-1',
          title: 'درخواست خرید',
          targetDoctype: 'Purchase Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 2,
          modified: null,
        ),
        stages: const [
          WorkflowStage(
            id: 'S-1',
            key: 'start',
            type: WorkflowStageType.start,
            title: 'شروع',
            sequence: 1,
            configurationComplete: true,
          ),
          WorkflowStage(
            id: 'S-2',
            key: 'action',
            type: WorkflowStageType.systemAction,
            title: 'اقدام خودکار',
            sequence: 2,
            configurationComplete: true,
          ),
        ],
        transitions: const [
          WorkflowTransition(
            id: 'T-1',
            fromStage: 'S-1',
            toStage: 'S-2',
            label: 'Continue',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: WorkflowGraphCanvas(
                design: design,
                onOpenStage: (_) {},
                onMoveStage: (_, __, ___) {},
                onMoveEnd: () {},
                onCreateTransition: (_) {},
                onInsertOnTransition: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue ←'), findsNothing);
      expect(find.text('ادامه ←'), findsOneWidget);
    });

    testWidgets(
        'Settings greeting maps English ERPNext roles and hides ASOUD-ACCESS-USER- ids',
        (tester) async {
      final client = _MockClient();
      when(() => client.isAuthenticated).thenReturn(true);
      when(() => client.getCurrentUser()).thenAnswer(
        (_) async => const FrappeUserContext(
          userId: 'Administrator',
          fullName: 'Administrator',
          roles: [
            'Administrator',
            'Academics User',
            'ASOUD-ACCESS-USER-ADMIN-ROLE',
            'Purchase Master Manager',
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: RepositoryProvider<FrappeApiClient>.value(
            value: client,
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: SettingsDashboardContent(
                company: 'شرکت نمونه آسود',
                offlinePreview: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ASOUD-ACCESS-USER-'), findsNothing);
      expect(find.textContaining('Academics User'), findsNothing);
      expect(find.textContaining('مدیر سامانه'), findsOneWidget);
      expect(find.textContaining('کاربر آموزش'), findsOneWidget);
      expect(find.textContaining('مدیر اطلاعات پایه خرید'), findsOneWidget);
    });
  });
}
