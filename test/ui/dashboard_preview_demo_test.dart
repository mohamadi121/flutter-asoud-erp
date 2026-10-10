import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/employee/presentation/pages/employee_shell.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/frappe_office_repository.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/server_first_office_repository.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/office_setup/data/demo/office_demo_data.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_local_record_store.dart';

class _Client extends Mock implements FrappeApiClient {}

Widget _app(Widget page, _Client client) => MaterialApp(
      theme: AsoudTheme.light,
      home: RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: Directionality(textDirection: TextDirection.rtl, child: page),
      ),
    );

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository(this.office);

  Office? office;

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

Widget _landingApp({
  required _Client client,
  required OfficeRepository offices,
  required OfflineSyncService sync,
}) =>
    MaterialApp(
      theme: AsoudTheme.light,
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FrappeApiClient>.value(value: client),
          RepositoryProvider<OfficeRepository>.value(value: offices),
          RepositoryProvider<OfflineSyncService>.value(value: sync),
        ],
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: DashboardLandingPage(),
        ),
      ),
    );

void main() {
  late _Client client;
  setUp(() {
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
    when(() => client.getCurrentUser()).thenThrow(Exception('offline'));
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('preview dashboard shows the demo office and figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final office = demoPreviewOffice();
      await tester.pumpWidget(_app(
          DashboardPage(
              office: office, officeName: office.name, offlinePreview: true),
          client));
      await tester.pumpAndSettle();

      expect(find.text('شرکت نمونه آسود'), findsWidgets);
      expect(find.text('۱۲٬۴۵۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۸٬۲۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۴۵۶٬۷۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('۶ سند'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('استاندارد ایران'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('استاندارد ایران'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('طرف حساب‌ها'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('طرف حساب‌ها'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('preview settings show demo system figures at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
          const SettingsDashboardContent(
              company: demoCompanyName, offlinePreview: true),
          client));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('کاربران فعال'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('کاربران فعال'), findsOneWidget);
      expect(find.text('۱۴'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('۶۸٪'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('۶۸٪'), findsOneWidget);
      expect(find.text('نمایشی'), findsWidgets);
    });
  }

  testWidgets('setup card is hidden when the server marks setup complete',
      (tester) async {
    final office = Office(
        name: 'دفتر تکمیل‌شده',
        type: OfficeType.legal,
        fiscalYearStart: DateTime(2026),
        setupComplete: true);
    await tester.pumpWidget(
        _app(DashboardPage(office: office, officeName: office.name), client));
    await tester.pumpAndSettle();

    expect(find.text('راه‌اندازی دفتر هنوز کامل نیست'), findsNothing);
  });

  testWidgets('home refreshes setup status after sync', (tester) async {
    final incomplete = Office(
      name: 'دفتر نمونه',
      type: OfficeType.legal,
      fiscalYearStart: DateTime(2026),
    );
    final offices = _OfficeRepository(incomplete);
    final sync = OfflineSyncService(client, local: FakeLocalRecordStore());
    await tester.pumpWidget(
      _landingApp(client: client, offices: offices, sync: sync),
    );
    await tester.pumpAndSettle();
    expect(find.text('راه‌اندازی دفتر هنوز کامل نیست'), findsOneWidget);

    offices.office = Office(
      name: incomplete.name,
      type: incomplete.type,
      fiscalYearStart: incomplete.fiscalYearStart,
      setupComplete: true,
    );
    await sync.syncNow();
    await tester.pumpAndSettle();

    expect(find.text('راه‌اندازی دفتر هنوز کامل نیست'), findsNothing);
  });

  testWidgets(
      'کارمند با نقش‌های واقعی به پنل خود می‌رود و وضعیت دفتر را درخواست نمی‌کند',
      (tester) async {
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
          userId: 'sales-manager@asoud-demo.local',
          fullName: 'مدیر فروش',
          roles: ['Employee', 'Employee Self Service', 'Desk User'],
          employeeId: 'HR-EMP-0001',
          company: 'شرکت نمونه آسود',
        ));
    final offices = _OfficeRepository(null);
    final sync = OfflineSyncService(client, local: FakeLocalRecordStore());

    await tester.pumpWidget(
      _landingApp(client: client, offices: offices, sync: sync),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmployeeShell), findsOneWidget);
    expect(find.text('برای شروع، اطلاعات اولیه دفتر را ثبت کنید'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'خطای ۴۰۳ وضعیت دفتر برای حساب بدون دسترسی آفلاین یا راه‌اندازی جعلی نمی‌شود',
      (tester) async {
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.getCurrentUser()).thenAnswer((_) async =>
        const FrappeUserContext(
          userId: 'sales-manager@asoud-demo.local',
          fullName: 'مدیر فروش',
          roles: ['Employee', 'Employee Self Service', 'Desk User'],
        ));
    when(() => client.callAsoudMethod(
          'asoud_erp.api.v1.setup.get_setup_status',
          data: any(named: 'data'),
        )).thenThrow(const ApiException(
      kind: ApiFailureKind.forbidden,
      message: 'دسترسی ندارید',
      statusCode: 403,
    ));
    final offices = ServerFirstOfficeRepository(
      FrappeOfficeRepository(client),
      local: FakeLocalRecordStore(),
    );
    final sync = OfflineSyncService(client, local: FakeLocalRecordStore());

    await tester.pumpWidget(
      _landingApp(client: client, offices: offices, sync: sync),
    );
    await tester.pumpAndSettle();

    expect(find.text('برای این حساب دسترسی مدیریت دفتر تعریف نشده است'),
        findsOneWidget);
    expect(find.text('نسخه نمایشی آفلاین'), findsNothing);
    expect(find.text('برای شروع، اطلاعات اولیه دفتر را ثبت کنید'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
