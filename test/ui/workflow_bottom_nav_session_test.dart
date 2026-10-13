import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/data/demo/office_demo_data.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/workflow_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

class _ClientWithRoles extends Fake implements FrappeApiClient {
  _ClientWithRoles(this._roles);
  final List<String> _roles;

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => FrappeUserContext(
        userId: 'user@asoud-demo.local',
        fullName: 'کاربر آزمایشی',
        roles: _roles,
      );
}

class _WorkflowRepository extends Fake implements WorkflowRepository {
  @override
  Future<List<WorkflowDefinition>> getWorkflows({
    String? search,
    WorkflowDefinitionStatus? status,
    String? company,
    String orderBy = 'modified desc',
  }) async =>
      const [
        WorkflowDefinition(
          id: 'WF-1404-001',
          code: 'WF-1404-001',
          title: 'فرایند خرید کالا',
          targetDoctype: 'Material Request',
          status: WorkflowDefinitionStatus.active,
          isLocked: false,
          version: 1,
          stepsCount: 4,
          modified: null,
        ),
      ];
}

class _NotificationRepository extends Fake
    implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowNotification>> getNotifications(
          {bool unreadOnly = false}) async =>
      const [];

  @override
  Future<void> markRead(String notification) async {}
}

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository(this.office);

  final Office? office;

  @override
  Future<Office> createOffice(Office office) => throw UnimplementedError();

  @override
  Future<Office?> getDefaultOffice() async => office;

  @override
  Future<List<Office>> listOffices() => throw UnimplementedError();

  @override
  Future<Office> setDefaultOffice(Office office) => throw UnimplementedError();

  @override
  Future<Office> updateOffice(String id, Office office) =>
      throw UnimplementedError();
}

Widget _app({required FrappeApiClient client}) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrappeApiClient>.value(value: client),
        RepositoryProvider<WorkflowRepository>.value(
            value: _WorkflowRepository()),
        RepositoryProvider<WorkflowNotificationRepository>.value(
            value: _NotificationRepository()),
        RepositoryProvider<OfficeRepository>.value(
            value: _OfficeRepository(demoPreviewOffice())),
        RepositoryProvider<OfflineSyncService>.value(
            value: OfflineSyncService(client, local: FakeLocalRecordStore())),
      ],
      child: MaterialApp(
        theme: AsoudTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: WorkflowListPage(),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final (label, roles) in [
    ('Administrator', <String>['Administrator']),
    ('HR Manager', <String>['HR Manager', 'Employee']),
  ]) {
    testWidgets(
        'کاربر واردشده با نقش $label از نوار پایین گردش‌کار به نسخه نمایشی آفلاین نمی‌رود',
        (tester) async {
      final client = _ClientWithRoles(roles);
      await tester.pumpWidget(_app(client: client));
      await tester.pumpAndSettle();
      expect(find.text('گردش‌کارها'), findsOneWidget);

      await tester.tap(find.text('داشبورد'));
      await tester.pumpAndSettle();
      expect(find.text('نسخه نمایشی آفلاین'), findsNothing);
      expect(find.text('ورود به حساب سازمانی'), findsNothing);
      expect(find.text('گردش‌کارها'), findsOneWidget);

      await tester.tap(find.text('اعلان‌ها'));
      await tester.pumpAndSettle();
      expect(find.text('نسخه نمایشی آفلاین'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('بیشتر'));
      await tester.pumpAndSettle();
      expect(find.text('نسخه نمایشی آفلاین'), findsNothing);
      expect(find.text('ورود به حساب سازمانی'), findsNothing);
      expect(find.text('گردش‌کارها'), findsOneWidget);

      expect(client.isAuthenticated, isTrue);
    });
  }

  testWidgets('نشست نمایشی بدون ورود همچنان به نسخه نمایشی آفلاین می‌رسد',
      (tester) async {
    final client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    await tester.pumpWidget(_app(client: client));
    await tester.pumpAndSettle();
    expect(find.text('گردش‌کارها'), findsOneWidget);

    await tester.tap(find.text('داشبورد'));
    await tester.pumpAndSettle();

    expect(find.text('نسخه نمایشی آفلاین'), findsOneWidget);
  });
}
