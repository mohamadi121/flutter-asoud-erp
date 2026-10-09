import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/office_setup/domain/repositories/office_repository.dart';
import 'package:asoud_erp/features/office_setup/presentation/cubit/offices_cubit.dart';
import 'package:asoud_erp/features/office_setup/presentation/pages/offices_page.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_local_record_store.dart';
import '../helpers/fake_office_repository.dart';

void main() {
  final defaultOffice = Office(
    name: 'شرکت نمونه آسود',
    type: OfficeType.legal,
    fiscalYearStart: DateTime(2026),
  );

  testWidgets(
      'صفحه دفترها در حالت بدون جست‌وجو عبارت پیدا نشد نشان نمی‌دهد و منوی بالا گزینه‌ها را باز می‌کند',
      (tester) async {
    final repository = FakeOfficeRepository(
      offices: [defaultOffice],
      defaultOffice: defaultOffice,
    );

    await tester.pumpWidget(
      RepositoryProvider<OfficeRepository>.value(
        value: repository,
        child: MaterialApp(
          locale: const Locale('fa'),
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: OfficesPage(
              initialState: OfficesState(
                status: OfficesStatus.success,
                offices: [defaultOffice],
                defaultOffice: defaultOffice,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دفتری با این عبارت پیدا نشد.'), findsNothing);
    expect(find.text('دفتر دیگری ثبت نشده است.'), findsOneWidget);

    final topMenu = find.byTooltip('منوی بیشتر');
    expect(topMenu, findsOneWidget);
    await tester.tap(topMenu);
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
    expect(find.text('به‌روزرسانی فهرست'), findsOneWidget);
  });

  test('متدهای خواندنی Asoud به عنوان جهش آفلاین شمرده نمی‌شوند', () {
    expect(FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.roles.catalog'),
        isTrue);
    expect(
        FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.hr.organization_tree'),
        isTrue);
    expect(
        FrappeClient.isReadOnlyMethod('asoud_erp.api.v1.user_access.directory'),
        isTrue);
    expect(
        FrappeClient.isReadOnlyMethod(
            'asoud_erp.api.v1.roles.permission_preview'),
        isTrue);

    final readRecord = LocalRecord(
      id: 'm1',
      entityType: 'asoud_erp.api.v1.roles.catalog',
      payload: const {'operation': 'asoud_method'},
      status: LocalSyncStatus.syncFailed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(isQueuedMutation(readRecord), isFalse);

    final writeRecord = LocalRecord(
      id: 'm2',
      entityType: 'asoud_erp.api.v1.setup.save_office',
      payload: const {'operation': 'asoud_method'},
      status: LocalSyncStatus.pendingSync,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(isQueuedMutation(writeRecord), isTrue);
  });

  test('دریافت انواع درخواست گردش‌کارهای فعال سرور را ترکیب می‌کند', () async {
    final client = _StubWorkflowClient();
    final store = FakeLocalRecordStore();
    final repo =
        GenericRequestRepository(client, 'شرکت نمونه آسود', store: store);

    final options = await repo.options();
    expect(options, isNotEmpty);
    final codes = options.map((r) => r['workflow_code']).toSet();
    expect(codes.contains('ASOUD-DEMO-PURCHASE'), isTrue);
    expect(codes.contains('SYS-PURCHASE-WP'), isTrue);
    final sysPurchase =
        options.firstWhere((r) => r['workflow_code'] == 'SYS-PURCHASE-WP');
    expect(sysPurchase['template_key'], 'purchase');
  });
}

class _StubWorkflowClient extends Fake implements FrappeApiClient {
  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
        userId: 'Administrator',
        fullName: 'Administrator',
        roles: ['System Manager'],
      );

  @override
  Future<dynamic> callAsoudMethod(String method,
      {Map<String, dynamic>? data}) async {
    if (method == 'asoud_erp.api.v1.workflow_request.request_options') {
      return [
        {
          'name': 'ASOUD-DEMO-PURCHASE',
          'workflow_code': 'ASOUD-DEMO-PURCHASE',
          'workflow_title': 'درخواست خرید نمونه',
          'short_title': 'درخواست خرید نمونه',
          'template_key': '',
          'fields': [],
        },
      ];
    }
    if (method == 'asoud_erp.api.v1.workflow.list_workflows') {
      return [
        {
          'name': 'SYS-PURCHASE-WP',
          'workflow_code': 'SYS-PURCHASE-WP',
          'workflow_title': 'درخواست خرید کالا',
          'short_title': 'ثبت درخواست خرید کالا',
          'target_doctype': 'ASOUD Workflow Request',
          'allow_user_submission': true,
          'template_key': 'purchase',
          'icon_key': 'purchase',
          'color_hex': '#1769F6',
        },
      ];
    }
    return [];
  }
}
