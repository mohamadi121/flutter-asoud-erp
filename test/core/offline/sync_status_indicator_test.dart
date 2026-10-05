import 'dart:async';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/offline/offline_sync_service.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/settings_dashboard_content.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/sync_queue_page.dart';
import 'package:asoud_erp/features/dashboard/presentation/pages/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_local_record_store.dart';

class _IndicatorClient extends Fake implements FrappeApiClient {
  Completer<void>? gate;

  @override
  bool get isAuthenticated => true;

  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'user', fullName: 'کاربر آزمون', roles: []);

  @override
  Future<dynamic> replayOfflineMutation({
    required String mutationId,
    required String operation,
    required String target,
    required Map<String, dynamic> data,
  }) async {
    await gate?.future;
    return {'name': 'REMOTE-1'};
  }
}

Future<void> _queue(FakeLocalRecordStore store, String id) => store.save(
      id: id,
      entityType: 'asoud_erp.api.v1.party.save_party',
      payload: {
        'operation': 'asoud_method',
        '_asoud_owner': 'user',
        '_asoud_server': 'injected-client',
        'name': 'PARTY-$id',
      },
      status: LocalSyncStatus.pendingSync,
    );

Widget _app(Widget child) => MaterialApp(
      theme: AsoudTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeLocalRecordStore store;
  late _IndicatorClient client;
  late OfflineSyncService service;

  setUp(() {
    store = FakeLocalRecordStore();
    client = _IndicatorClient();
    service = OfflineSyncService(client, local: store);
  });

  testWidgets('نشانگر شمار نوشته‌های ارسال‌نشده را با ارقام فارسی می‌گوید',
      (tester) async {
    await _queue(store, 'one');
    await _queue(store, 'two');
    await _queue(store, 'three');

    await tester.pumpWidget(_app(SyncStatusIndicator(service: service)));
    await _settle(tester);

    expect(find.text('۳ نوشته ارسال نشده'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('صف خالی با تیک سبز «همه داده‌ها ارسال شده» نشان داده می‌شود',
      (tester) async {
    await tester.pumpWidget(_app(SyncStatusIndicator(service: service)));
    await _settle(tester);

    expect(find.text('همه داده‌ها ارسال شده'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(icon.color, AsoudColors.success);
  });

  testWidgets('هنگام ارسال، نشانگر چرخان است و پس از پایان به‌روز می‌شود',
      (tester) async {
    await _queue(store, 'one');
    client.gate = Completer<void>();
    await tester.pumpWidget(_app(SyncStatusIndicator(service: service)));
    await _settle(tester);
    expect(find.text('۱ نوشته ارسال نشده'), findsOneWidget);

    unawaited(service.syncNow());
    await _settle(tester);

    expect(service.isSyncing, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('۱ نوشته ارسال نشده'), findsOneWidget);

    client.gate!.complete();
    await _settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('همه داده‌ها ارسال شده'), findsOneWidget);
  });

  testWidgets('نشانگر با تغییر صف خودش را تازه می‌کند', (tester) async {
    await _queue(store, 'one');
    await _queue(store, 'two');
    await tester.pumpWidget(_app(SyncStatusIndicator(service: service)));
    await _settle(tester);
    expect(find.text('۲ نوشته ارسال نشده'), findsOneWidget);

    await service.discard('one');
    await _settle(tester);

    expect(find.text('۱ نوشته ارسال نشده'), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('نشانگر در نوار بالای داشبورد عرض $width سرریز نمی‌کند',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _queue(store, 'one');

      await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
        value: client,
        child: RepositoryProvider<OfflineSyncService>.value(
          value: service,
          child: _app(DashboardPage(
            officeName: 'دفتر نمونه',
            offlinePreview: true,
            onOfficeCreated: () =>
                fail('نباید صف ارسال به ساخت دفتر ربطی داشته باشد'),
          )),
        ),
      ));
      await _settle(tester);

      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('نشانگر نوار بالا صف ارسال را باز می‌کند', (tester) async {
    await _queue(store, 'one');
    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: RepositoryProvider<OfflineSyncService>.value(
        value: service,
        child: _app(const DashboardPage(
            officeName: 'دفتر نمونه', offlinePreview: true)),
      ),
    ));
    await _settle(tester);

    await tester.tap(find.byType(SyncStatusIndicator));
    await _settle(tester);

    expect(find.byType(SyncQueuePage), findsOneWidget);
    expect(find.text('ذخیره طرف حساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('کارت «وضعیت همگام‌سازی» در تنظیمات صف ارسال را باز می‌کند',
      (tester) async {
    await _queue(store, 'one');
    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: RepositoryProvider<OfflineSyncService>.value(
        value: service,
        child: _app(const DashboardPage(
            officeName: 'دفتر نمونه', offlinePreview: true)),
      ),
    ));
    await _settle(tester);

    await tester.tap(find.text('تنظیمات'));
    await _settle(tester);
    expect(find.byType(SettingsDashboardContent), findsOneWidget);

    await tester.ensureVisible(find.text('وضعیت همگام‌سازی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('وضعیت همگام‌سازی'));
    await _settle(tester);

    expect(find.byType(SyncQueuePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
