import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/queued_offline_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/frappe_office_repository.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/server_first_office_repository.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/office_type_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_local_record_store.dart';

class _FakeSetupClient extends Fake implements FrappeApiClient {
  _FakeSetupClient({this.saveOfficeHandler});

  Future<dynamic> Function(Map<String, dynamic>? data)? saveOfficeHandler;
  final calls = <String>[];
  Map<String, dynamic>? lastSaveOfficeData;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: ['Administrator', 'System Manager', 'Accounts Manager'],
      );

  @override
  Future<dynamic> callAsoudMethod(
    String method, {
    Map<String, dynamic>? data,
  }) async {
    calls.add(method);
    if (method == 'asoud_erp.api.v1.setup.save_office') {
      lastSaveOfficeData = data;
      if (saveOfficeHandler != null) {
        return saveOfficeHandler!(data);
      }
      final chartTemplate = data?['chart_template'];
      const allowedTemplates = {
        'Iran Standard',
        'Service',
        'Commercial',
        'Manufacturing'
      };
      if (chartTemplate != null && !allowedTemplates.contains(chartTemplate)) {
        throw ApiException(
          kind: ApiFailureKind.validation,
          message:
              'Chart Template cannot be "$chartTemplate". It should be one of "Iran Standard", "Service", "Commercial", "Manufacturing"',
          statusCode: 417,
        );
      }
      return {
        'company': data?['company_name'] ?? 'شرکت تست آسود',
        'office_type': data?['office_type'] ?? 'Personal',
        'national_id': data?['national_id'] ?? '',
        'economic_code': data?['economic_code'] ?? '',
        'owner_full_name': data?['owner_full_name'] ?? '',
        'registration_number': data?['registration_number'] ?? '',
        'activity_type': 'Commercial',
        'company_type': '',
        'parent_office': '',
        'phone': '',
        'email': '',
        'website': '',
        'province': 'Tehran',
        'city': 'Tehran',
        'address': '',
        'postal_code': '',
        'description': '',
        'modified': '2026-10-10 10:00:00',
        'accounting_basis': 'Accrual',
        'display_currency': 'Rial',
        'fiscal_year_start_month': 1,
        'fiscal_year_start_day': 1,
        'fiscal_year': 1405,
        'chart_template': chartTemplate ?? 'Iran Standard',
        'auto_generate_detail_code': true,
        'enabled_roles': ['System Manager'],
        'office_saved': true,
        'accounting_saved': false,
        'roles_saved': false,
        'complete': false,
      };
    }
    if (method == 'asoud_erp.api.v1.setup.get_setup_status') {
      return {
        'company': 'شرکت تست آسود',
        'office_type': 'Personal',
        'office_saved': true,
        'accounting_saved': false,
        'roles_saved': false,
        'complete': false,
      };
    }
    throw UnimplementedError('Method $method not stubbed');
  }
}

Widget _wrap(Widget child,
    {required FrappeApiClient client, required OfficeRepository repository}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FrappeApiClient>.value(value: client),
      RepositoryProvider<OfficeRepository>.value(value: repository),
    ],
    child: MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets(
      'مسیر ایجاد دفتر: نوع دفتر -> فرم -> ارسال با پاسخ واقعی سرور به داشبورد هدایت می‌شود',
      (tester) async {
    final client = _FakeSetupClient();
    final localStore = FakeLocalRecordStore();
    final repository = ServerFirstOfficeRepository(
      FrappeOfficeRepository(client),
      local: localStore,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
        _wrap(const OfficeTypePage(), client: client, repository: repository));
    await tester.pumpAndSettle();

    // Name field is required
    await tester.enterText(
      find.byKey(const ValueKey('office-officeName-0')),
      'شرکت تست آسود',
    );
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, 'ایجاد دفتر کار');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(client.calls, contains('asoud_erp.api.v1.setup.save_office'));
    // The chart template sent to backend must be accepted by Frappe
    expect(client.lastSaveOfficeData?['chart_template'], 'Iran Standard');
    // Successfully arrives on DashboardPage with the office name
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('شرکت تست آسود'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'مسیر ایجاد دفتر: QueuedOfflineException به offlinePreview با پیام صف هدایت می‌شود',
      (tester) async {
    final client = _FakeSetupClient(
      saveOfficeHandler: (_) async =>
          throw const QueuedOfflineException(localId: 'Q-OFFICE-1'),
    );
    final localStore = FakeLocalRecordStore();
    final repository = ServerFirstOfficeRepository(
      FrappeOfficeRepository(client),
      local: localStore,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
        _wrap(const OfficeTypePage(), client: client, repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('office-officeName-0')),
      'دفتر کار آفلاین',
    );
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, 'ایجاد دفتر کار');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Navigates to DashboardPage with offline mode
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('دفتر کار آفلاین'), findsWidgets);
    expect(find.text('حالت موقت آفلاین'), findsOneWidget);
    expect(find.text(QueuedOfflineException.queuedFeedback), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'مسیر ایجاد دفتر: خطای شبکه با allowOfflinePreview=false وضعیت failure نشان می‌دهد',
      (tester) async {
    final client = _FakeSetupClient(
      saveOfficeHandler: (_) async => throw const ApiException(
        kind: ApiFailureKind.network,
        message: 'ارتباط با سرور برقرار نشد.',
      ),
    );
    final localStore = FakeLocalRecordStore();
    final repository = ServerFirstOfficeRepository(
      FrappeOfficeRepository(client),
      local: localStore,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_wrap(
      const OfficeTypePage(allowOfflinePreview: false),
      client: client,
      repository: repository,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('office-officeName-0')),
      'دفتر شبکه قطع',
    );
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, 'ایجاد دفتر کار');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Remains on form and shows the error message
    expect(find.byType(DashboardPage), findsNothing);
    expect(find.text('ارتباط با سرور برقرار نشد.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'مسیر ایجاد دفتر: در صورت خطای سرور پیام خطای فارسی در فرم نمایش داده می‌شود',
      (tester) async {
    final client = _FakeSetupClient(
      saveOfficeHandler: (_) async => throw const ApiException(
        kind: ApiFailureKind.forbidden,
        message: 'شما دسترسی ایجاد شرکت را ندارید.',
        statusCode: 403,
      ),
    );
    final localStore = FakeLocalRecordStore();
    final repository = ServerFirstOfficeRepository(
      FrappeOfficeRepository(client),
      local: localStore,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
        _wrap(const OfficeTypePage(), client: client, repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('office-officeName-0')),
      'دفتر بدون دسترسی',
    );
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, 'ایجاد دفتر کار');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Remains on form and shows the Persian error message
    expect(find.byType(DashboardPage), findsNothing);
    expect(find.text('شما دسترسی ایجاد شرکت را ندارید.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
