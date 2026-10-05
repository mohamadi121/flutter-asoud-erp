import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/workflows/data/workflow_automation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements FrappeApiClient {}

void main() {
  late _Client client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    when(() => client.isAuthenticated).thenReturn(false);
  });

  test('preview offers three demo templates built from presets', () async {
    final repository = WorkflowAutomationRepository(client);
    expect(repository.isLocal, isTrue);
    final rows = await repository.templates(company: 'شرکت نمونه آسود');
    expect(
        rows.map((row) => row.title),
        containsAll(
            ['سند هزینه خرید', 'پرداخت به تأمین‌کننده', 'سند هزینه عمومی']));
    expect(rows, hasLength(3));
    for (final row in rows) {
      expect(row.isReady, isFalse);
      expect(row.presetKey, isNotEmpty);
    }
    final purchase =
        rows.firstWhere((row) => row.presetKey == 'purchase_expense');
    expect(purchase.mapping['amount']!.source, 'request');
    expect(purchase.mapping['amount']!.value, 'total');
    expect(purchase.mapping['debit_account']!.value, 'هزینه خرید - نمونه');
    final filtered = await repository.templates(
        company: 'شرکت نمونه آسود', module: 'Finance');
    expect(filtered, hasLength(3));
  });

  test('a saved template replaces the demos in preview', () async {
    final repository = WorkflowAutomationRepository(client);
    expect(
        await repository.templates(company: 'شرکت نمونه آسود'), hasLength(3));
    final ready =
        await repository.templates(company: 'شرکت نمونه آسود', kind: 'ready');
    await repository.saveTemplate(
        company: 'شرکت نمونه آسود',
        template:
            ready.firstWhere((row) => row.presetKey == 'general_expense'));
    final custom = await repository.templates(company: 'شرکت نمونه آسود');
    expect(custom, hasLength(1));
    expect(custom.single.title, 'سند هزینه عمومی');
  });

  test('an authenticated session never sees the demo templates', () async {
    when(() => client.isAuthenticated).thenReturn(true);
    when(() => client.callAsoudMethod(any(), data: any(named: 'data')))
        .thenAnswer((_) async => <dynamic>[]);
    final repository = WorkflowAutomationRepository(client);
    expect(repository.isLocal, isFalse);
    expect(await repository.templates(company: 'شرکت نمونه آسود'), isEmpty);
  });
}
