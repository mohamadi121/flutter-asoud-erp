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
        : {'job': 'a' * 40, 'state': state, 'message': 'نتیجهٔ ثبت‌شده در سرور'}}};
  }
}

void main() {
  for (final state in ['completed', 'failed']) {
    testWidgets('resumes a $state reset without resubmitting deletion', (tester) async {
      final client = Client(state);
      bool? result;
      await tester.pumpWidget(RepositoryProvider<FrappeApiClient>.value(value: client,
        child: MaterialApp(theme: AsoudTheme.light, home: Builder(builder: (context) => Scaffold(
          body: TextButton(onPressed: () async {
            result = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const SetupResetPage()));
          }, child: const Text('باز کردن')))))));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(client.calls.any((method) => method.endsWith('.perform')), isFalse);
      if (state == 'completed') {
        expect(result, isTrue);
        expect(find.byType(SetupResetPage), findsNothing);
      } else {
        expect(result, isNull);
        expect(find.text('نتیجهٔ ثبت‌شده در سرور'), findsOneWidget);
        expect(find.byType(SetupResetPage), findsOneWidget);
      }
    });
  }
}
