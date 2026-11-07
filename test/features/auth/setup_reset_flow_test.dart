import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_database_store.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/presentation/pages/setup_reset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Payloads follow docs/api/setup-reset.md and services/setup_reset.py.
Map<String, dynamic> preview() => {
      'token': 'p' * 40,
      'companies': ['دفتر آزمایشی'],
      'counts': {'Company': 1},
      'blockers': <String>[],
      'preserved': ['شناسهٔ حساب مدیر، نام کاربری، رمز و دسترسی مدیر سیستم'],
    };

class _Store extends Fake implements LocalRecordStore {
  final records = <LocalRecord>[];
  @override
  Future<List<LocalRecord>> list(
          {String? entityType, Set<LocalSyncStatus>? statuses}) async =>
      records
          .where((r) => statuses == null || statuses.contains(r.status))
          .toList();
}

class _Client extends Fake implements FrappeClient {
  @override
  String get serverIdentity => 'https://erp.example.test';
  final plan = preview();
  final calls = <(String, Map<String, dynamic>)>[];
  final states = ['queued', 'running', 'completed'];
  bool losePerformResponse = false;
  bool failStatus = false;
  @override
  Future<FrappeUserContext> getCurrentUser() async => const FrappeUserContext(
      userId: 'admin@example.test',
      fullName: 'مدیر',
      roles: ['System Manager']);
  @override
  Future<Map<String, dynamic>> callMethod(String method,
      {Map<String, dynamic>? data}) async {
    final name = method.split('.').last;
    calls.add((name, Map.of(data ?? {})));
    late Map<String, dynamic> result;
    switch (name) {
      case 'preview':
        result = plan;
      case 'perform':
        if (losePerformResponse) {
          throw const ApiException(
              kind: ApiFailureKind.timeout,
              message: 'مهلت دریافت پاسخ پایان یافت.');
        }
        result = {'job': 'j' * 40};
      case 'status':
        if (failStatus) {
          throw const ApiException(
              kind: ApiFailureKind.timeout,
              message: 'مهلت دریافت پاسخ پایان یافت.');
        }
        if (data!.containsKey('preview_token')) {
          if (!calls.any((c) => c.$1 == 'perform')) {
            throw const ApiException.protocol();
          }
          result = {'job': 'j' * 40, 'state': 'queued', 'message': null};
        } else {
          final state = states.length > 1 ? states.removeAt(0) : states.single;
          result = {
            'job': 'j' * 40,
            'state': state,
            'message': 'وضعیت بازنشانی',
            if (state == 'completed') 'actor': 'admin@example.test',
            if (state == 'completed') 'companies': ['دفتر آزمایشی']
          };
        }
      default:
        throw StateError('Unexpected reset method');
    }
    return {
      'message': {
        'ok': true,
        'data': result,
        'meta': {'api_version': 'v1'}
      }
    };
  }
}

Future<void> _open(WidgetTester tester, _Client client, _Store store,
    {required double width,
    required Future<void> Function(String, List<String>) cleanup}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(
      value: client,
      child: MaterialApp(
          theme: AsoudTheme.light,
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SetupResetPage(
                                  localStore: store,
                                  onResetConfirmed: cleanup))),
                      child: const Text('باز کردن')))))));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  final confirmation =
      find.widgetWithText(TextField, 'عبارت «شروع دوباره» را دقیق وارد کنید');
  await tester.ensureVisible(confirmation);
  await tester.enterText(confirmation, 'شروع دوباره');
  final password = find.widgetWithText(TextField, 'تأیید مجدد رمز حساب مدیر');
  await tester.ensureVisible(password);
  await tester.enterText(password, 'test-only-password');
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final lostResponse in [false, true]) {
      testWidgets(
          'confirmed preview performs once and follows status at $width, lost=$lostResponse',
          (tester) async {
        final client = _Client()..losePerformResponse = lostResponse;
        var cleanups = 0;
        final store = _Store();
        store.records.add(LocalRecord(
            id: 'org-v2:${Uri.encodeComponent(jsonEncode([
                  client.serverIdentity,
                  'admin@example.test',
                  'دفتر آزمایشی'
                ]))}:archive:123',
            entityType: 'organization_draft_archive',
            payload: const {},
            status: LocalSyncStatus.localOnly,
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025)));
        await _open(tester, client, store, width: width,
            cleanup: (actor, companies) async {
          expect(actor, 'admin@example.test');
          expect(companies, ['دفتر آزمایشی']);
          cleanups++;
        });
        expect(client.calls.map((c) => c.$1), ['preview']);
        await confirm(tester);
        expect(client.calls.where((c) => c.$1 == 'perform'), hasLength(1));
        expect(client.calls.firstWhere((c) => c.$1 == 'perform').$2, {
          'token': 'p' * 40,
          'password': 'test-only-password',
          'confirmation': 'شروع دوباره',
          'backup_confirmed': 1,
        });
        expect(cleanups, 0);
        await tester.pump(const Duration(seconds: 2));
        expect(cleanups, 0);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(cleanups, 1);
        expect(find.byType(SetupResetPage), findsNothing);
        expect(client.calls.where((c) => c.$1 == 'perform'), hasLength(1));
        expect(client.calls.any((c) => c.$2['preview_token'] == 'p' * 40),
            lostResponse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows blocker details and prevents deletion at $width RTL',
        (tester) async {
      final client = _Client();
      client.plan.addAll({
        'blockers': [
          'نقش اختصاصی به حساب دیگری دسترسی داده است؛ حذف این دسترسی بدون بررسی مجاز نیست.'
        ],
        'blocking_users': ['outside@example.test'],
        'blocking_roles': [
          {
            'user': 'outside@example.test',
            'role': 'نقش خرید',
            'native_role': 'ASOUD-ACCESS-USER-internal'
          }
        ],
      });
      await _open(tester, client, _Store(),
          width: width,
          cleanup: (actor, companies) async => fail('Must not clean up'));
      await tester.scrollUntilVisible(find.text('نقش خرید'), 200);
      expect(find.text('نقش خرید'), findsOneWidget);
      expect(find.text('outside@example.test'), findsWidgets);
      final email = tester.widget<Text>(find.text('outside@example.test').last);
      expect(email.textDirection, TextDirection.ltr);
      expect(find.textContaining('ASOUD-ACCESS-USER'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(client.calls.map((c) => c.$1), ['preview']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('new blocker list alone still prevents deletion', (tester) async {
    final client = _Client();
    client.plan['blocking_users'] = ['outside@example.test'];
    await _open(tester, client, _Store(),
        width: 390,
        cleanup: (actor, companies) async => fail('Must not clean up'));
    await tester.scrollUntilVisible(find.text('outside@example.test'), 200);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(client.calls.map((c) => c.$1), ['preview']);
  });

  testWidgets('failed server reset keeps the page and never clears caches',
      (tester) async {
    final client = _Client()..states.replaceRange(0, 3, ['failed']);
    await _open(tester, client, _Store(),
        width: 390,
        cleanup: (actor, companies) async => fail('Must not clean up'));
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.text('وضعیت بازنشانی'), findsOneWidget);
    expect(find.byType(SetupResetPage), findsOneWidget);
    expect(client.calls.where((c) => c.$1 == 'perform'), hasLength(1));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('status timeout allows retry without repeating deletion',
      (tester) async {
    final client = _Client()..failStatus = true;
    var cleanups = 0;
    await _open(tester, client, _Store(), width: 390,
        cleanup: (actor, companies) async {
      cleanups++;
    });
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(cleanups, 0);
    await tester.scrollUntilVisible(
        find.textContaining('نتیجهٔ بازنشانی هنوز تأیید نشده'), -250);
    expect(
        find.textContaining('نتیجهٔ بازنشانی هنوز تأیید نشده'), findsOneWidget);
    client.failStatus = false;
    client.states.replaceRange(0, 3, ['completed']);
    await tester.ensureVisible(find.text('دریافت دوبارهٔ وضعیت'));
    await tester.tap(find.text('دریافت دوبارهٔ وضعیت'));
    await tester.pumpAndSettle();
    expect(cleanups, 1);
    expect(client.calls.where((c) => c.$1 == 'perform'), hasLength(1));
  });

  for (final status in LocalSyncStatus.values) {
    testWidgets(
        'offline queue preflight handles $status with owner and server scope',
        (tester) async {
      final client = _Client();
      final store = _Store();
      for (final scope in [
        ['admin@example.test', client.serverIdentity],
        ['other@example.test', client.serverIdentity],
        ['admin@example.test', 'https://other.example.test'],
      ]) {
        store.records.add(LocalRecord(
            id: scope.join(':'),
            entityType: 'request',
            payload: {'_asoud_owner': scope[0], '_asoud_server': scope[1]},
            status: status,
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025)));
      }
      await _open(tester, client, store,
          width: 390,
          cleanup: (actor, companies) async => fail('Must not clean up'));
      if (status == LocalSyncStatus.synced) {
        await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250);
        expect(find.byType(CheckboxListTile), findsOneWidget);
      } else {
        await tester.scrollUntilVisible(
            find.textContaining('۱ عملیات آفلاین تعیین‌تکلیف‌نشده'), 250);
        expect(find.textContaining('۱ عملیات آفلاین تعیین‌تکلیف‌نشده'),
            findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
      }
      expect(client.calls.map((c) => c.$1), ['preview']);
    });
  }

  testWidgets('unsent work appearing after preview stops perform',
      (tester) async {
    final client = _Client();
    final store = _Store();
    await _open(tester, client, store,
        width: 390,
        cleanup: (actor, companies) async => fail('Must not clean up'));
    store.records.add(LocalRecord(
        id: 'local-write',
        entityType: 'request',
        payload: const {
          '_asoud_owner': 'admin@example.test',
          '_asoud_server': 'https://erp.example.test'
        },
        status: LocalSyncStatus.syncFailed,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025)));
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(
        find.textContaining('ابتدا صف آن را تعیین تکلیف کنید'), findsOneWidget);
    expect(client.calls.where((c) => c.$1 == 'perform'), isEmpty);
  });
}
