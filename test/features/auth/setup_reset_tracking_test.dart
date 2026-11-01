import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/presentation/pages/setup_reset_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class Client extends Fake implements FrappeApiClient {
  Client(this.state);
  final String state;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> callMethod(String method, {Map<String, dynamic>? data}) async {
    calls.add(method);
    return {'message': {'ok': true, 'data': method.endsWith('.preview')
        ? {'job': 'a' * 40}
        : {'job': 'a' * 40, 'state': state, 'message': 'نتیجهٔ ثبت‌شده در سرور',
          if (state == 'completed') 'actor': 'admin', if (state == 'completed') 'companies': ['دفتر آزمایشی']}}};
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
  for (final state in ['completed', 'failed']) {
    testWidgets('resumes a $state reset without resubmitting deletion at $width RTL', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client(state);
      bool? result;
      final cleanups = <String>[];
      await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(value: client,
        child: MaterialApp(theme: AsoudTheme.light,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Builder(builder: (context) => Scaffold(
          body: TextButton(onPressed: () async {
            result = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => SetupResetPage(onResetConfirmed: (actor, companies) async {
                  expect(actor, 'admin');
                  cleanups.addAll(companies);
                })));
          }, child: const Text('باز کردن')))))));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(client.calls.any((method) => method.endsWith('.perform')), isFalse);
      if (state == 'completed') {
        expect(cleanups, ['دفتر آزمایشی']);
        expect(result, isTrue);
        expect(find.byType(SetupResetPage), findsNothing);
      } else {
        expect(cleanups, isEmpty);
        expect(result, isNull);
        expect(find.text('نتیجهٔ ثبت‌شده در سرور'), findsOneWidget);
        expect(find.byType(SetupResetPage), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  }

  testWidgets('cache failure retries only status and cleanup, never server deletion', (tester) async {
    final client = Client('completed');
    var attempts = 0;
    bool? result;
    await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(value: client,
      child: MaterialApp(theme: AsoudTheme.light, home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () async {
          result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
            SetupResetPage(onResetConfirmed: (actor, companies) async {
              if (++attempts == 1) throw StateError('local store unavailable');
            })));
        }, child: const Text('باز کردن')))))));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(result, isNull);
    expect(find.textContaining('حذف اطلاعات از سرور تأیید شد'), findsOneWidget);
    await tester.tap(find.text('دریافت دوبارهٔ وضعیت'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(result, isTrue);
    expect(client.calls.where((method) => method.endsWith('.status')), hasLength(2));
    expect(client.calls.any((method) => method.endsWith('.perform')), isFalse);
  });
}
