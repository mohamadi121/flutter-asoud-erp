import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/base_setup/presentation/pages/base_accounting_setup_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/office_setup/data/models/office_model.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/frappe_office_repository.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/server_first_office_repository.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_local_record_store.dart';

class _MockClient extends Mock implements FrappeApiClient {}

void main() {
  const realLiveStatus = <String, dynamic>{
    'company': 'شرکت نمونه آسود',
    'office_type': 'Legal',
    'national_id': '10101010101',
    'economic_code': '411111111111',
    'owner_full_name': 'علی محمدی',
    'registration_number': '123456',
    'activity_type': 'Commercial',
    'company_type': 'Private Joint Stock',
    'parent_office': '',
    'phone': '02188888888',
    'email': 'info@asoud.example',
    'website': 'https://asoud.example',
    'province': 'Tehran',
    'city': 'Tehran',
    'address': 'تهران، خیابان آزادی',
    'postal_code': '1234567890',
    'description': '',
    'modified': '2026-10-09 22:40:00.000000',
    'accounting_basis': 'Accrual',
    'display_currency': 'Rial',
    'fiscal_year_start_month': 1,
    'fiscal_year_start_day': 1,
    'fiscal_year': 1405,
    'chart_template': 'Iran Standard',
    'auto_generate_detail_code': true,
    'enabled_roles': ['System Manager'],
    'office_saved': true,
    'accounting_saved': true,
    'roles_saved': true,
    'complete': true,
  };

  const realLiveResourceListRow = <String, dynamic>{
    'company': 'شرکت نمونه آسود',
    'office_type': 'Legal',
    'national_id': '10101010101',
    'economic_code': '411111111111',
    'owner_full_name': 'علی محمدی',
    'registration_number': '123456',
    'activity_type': 'Commercial',
    'company_type': 'Private Joint Stock',
    'parent_office': null,
    'phone': '02188888888',
    'email': 'info@asoud.example',
    'website': 'https://asoud.example',
    'province': 'Tehran',
    'city': 'Tehran',
    'address': 'تهران، خیابان آزادی',
    'postal_code': '1234567890',
    'fiscal_year': '1405',
    'fiscal_year_start_month': 1,
    'chart_template': 'Iran Standard',
    'description': null,
    'auto_generate_detail_code': 1,
    'modified': '2026-10-09 22:40:00.000000',
    'office_saved': 1,
    'accounting_saved': 1,
    'roles_saved': 1,
  };

  group('T1 setup status & completion derivation', () {
    test('OfficeModel.fromSetup derives complete from saved flags', () {
      final officeFromRow = OfficeModel.fromSetup(realLiveResourceListRow);
      expect(officeFromRow.name, 'شرکت نمونه آسود');
      expect(officeFromRow.setupComplete, isTrue);

      final officeFromStatus = OfficeModel.fromSetup(realLiveStatus);
      expect(officeFromStatus.name, 'شرکت نمونه آسود');
      expect(officeFromStatus.setupComplete, isTrue);
    });

    test(
        'FrappeOfficeRepository listOffices queries saved flags and marks complete',
        () async {
      final client = _MockClient();
      when(() => client.getResourceList('ASOUD Company Setup',
          queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => [realLiveResourceListRow],
      );

      final repo = FrappeOfficeRepository(client);
      final list = await repo.listOffices();

      expect(list.length, 1);
      expect(list.first.name, 'شرکت نمونه آسود');
      expect(list.first.setupComplete, isTrue);
    });

    test(
        'ServerFirstOfficeRepository preserves setupComplete in local cache and restore',
        () async {
      final client = _MockClient();
      when(() => client.callAsoudMethod(
            'asoud_erp.api.v1.setup.get_setup_status',
            data: any(named: 'data'),
          )).thenAnswer((_) async => realLiveStatus);
      when(() => client.getResourceList('ASOUD Company Setup',
          queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => [realLiveResourceListRow],
      );

      final localStore = FakeLocalRecordStore();
      final frappeRepo = FrappeOfficeRepository(client);
      final serverFirst =
          ServerFirstOfficeRepository(frappeRepo, local: localStore);

      final initial = await serverFirst.getDefaultOffice();
      expect(initial?.setupComplete, isTrue);

      // Verify the cached local record preserved complete: true
      final cached = await serverFirst.listOffices();
      expect(cached.first.setupComplete, isTrue);

      // Verify restoring when remote is offline still returns setupComplete: true
      when(() => client.callAsoudMethod(
            'asoud_erp.api.v1.setup.get_setup_status',
            data: any(named: 'data'),
          )).thenThrow(const ApiException(
        kind: ApiFailureKind.network,
        message: 'offline',
      ));

      final offlineDefault = await serverFirst.getDefaultOffice();
      expect(offlineDefault?.setupComplete, isTrue);
    });

    testWidgets(
        'DashboardPage hides setup card when office setupComplete is true',
        (tester) async {
      final office = OfficeModel.fromSetup(realLiveStatus);
      final client = _MockClient();
      when(() => client.isAuthenticated).thenReturn(false);
      when(() => client.getCurrentUser()).thenThrow(Exception('offline'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: RepositoryProvider<FrappeApiClient>.value(
            value: client,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: DashboardPage(office: office, officeName: office.name),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('راه‌اندازی دفتر هنوز کامل نیست'), findsNothing);
      expect(find.text('تکمیل تنظیمات پایه'), findsNothing);
    });

    testWidgets(
        'BaseAccountingSetupPage shows 100% progress and completed text with real status',
        (tester) async {
      final client = _MockClient();
      when(() => client.callAsoudMethod(
            'asoud_erp.api.v1.setup.get_setup_status',
            data: any(named: 'data'),
          )).thenAnswer((_) async => realLiveStatus);

      final repo = FrappeOfficeRepository(client);

      await tester.pumpWidget(
        RepositoryProvider<OfficeRepository>.value(
          value: repo,
          child: MaterialApp(
            locale: const Locale('fa'),
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: BaseAccountingSetupPage(officeName: 'شرکت نمونه آسود'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('راه‌اندازی دفتر کامل شده است.'), findsOneWidget);
      expect(find.text('33,'), findsNothing);
      expect(find.text('راه‌اندازی دفتر هنوز کامل نیست.'), findsNothing);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 1.0);
    });
  });
}
