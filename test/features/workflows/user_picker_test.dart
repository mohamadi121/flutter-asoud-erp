import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/repositories/frappe_workflow_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {
  _Client(this.data);
  final dynamic data;
  @override
  bool get isAuthenticated => true;
  @override
  Future<dynamic> callAsoudMethod(String method,
          {Map<String, dynamic>? data}) async =>
      this.data;
}

Future<WorkflowFormOptions> _options(dynamic employees) async =>
    FrappeWorkflowRepository(_Client({
      'companies': <String>[],
      'modules': <Map<String, dynamic>>[],
      'roles': <String>[],
      'departments': <Map<String, dynamic>>[],
      'employees': employees,
    })).getFormOptions();

WorkflowTargetOption _person(String id, String label,
        {String? userId, String? designation, String? department}) =>
    WorkflowTargetOption(
        id: id,
        label: label,
        userId: userId,
        designation: designation,
        department: department);

/// Opens the picker and returns the future that resolves to the choice.
Future<Future<WorkflowTargetOption?>> _pick(WidgetTester tester,
    {required List<WorkflowTargetOption> employees,
    String? selectedUserId}) async {
  late Future<WorkflowTargetOption?> result;
  await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () {
                    result = pickUser(context,
                        employees: employees, selectedUserId: selectedUserId);
                  },
                  child: const Text('باز کردن'))))));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('parsing user_id', () {
    test('reads a present user_id', () async {
      final options = await _options([
        {
          'name': 'HR-EMP-1',
          'employee_name': 'علی رضایی',
          'user_id': 'ali@example.com'
        }
      ]);
      expect(options.employees.single.userId, 'ali@example.com');
    });

    test('missing user_id becomes null', () async {
      final options = await _options([
        {'name': 'HR-EMP-2', 'employee_name': 'سارا محمدی'}
      ]);
      expect(options.employees.single.userId, isNull);
    });

    test('empty user_id becomes null', () async {
      final options = await _options([
        {'name': 'HR-EMP-3', 'employee_name': 'رضا کریمی', 'user_id': ''}
      ]);
      expect(options.employees.single.userId, isNull);
    });
  });

  group('pickUser', () {
    testWidgets('hides employees without a user account', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pick(tester, employees: [
        _person('e1', 'علی رضایی', userId: 'ali@example.com'),
        _person('e2', 'سارا محمدی'),
      ]);
      expect(find.text('علی رضایی'), findsOneWidget);
      expect(find.text('سارا محمدی'), findsNothing);
    });

    testWidgets('search matches ي as ی and ك as ک', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pick(tester, employees: [
        _person('e1', 'علی رضایی', userId: 'ali@example.com'),
        _person('e2', 'سارا محمدی', userId: 'sara@example.com'),
      ]);
      await tester.enterText(find.byType(TextField), 'سارا محمدي');
      await tester.pumpAndSettle();
      expect(find.text('سارا محمدی'), findsOneWidget);
      expect(find.text('علی رضایی'), findsNothing);
    });

    testWidgets('returns the chosen option with its userId', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pick = await _pick(tester, employees: [
        _person('e1', 'علی رضایی', userId: 'ali@example.com'),
        _person('e2', 'سارا محمدی', userId: 'sara@example.com'),
      ]);
      await tester.tap(find.text('سارا محمدی'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تأیید انتخاب'));
      await tester.pumpAndSettle();
      final result = await pick;
      expect(result, isNotNull);
      final chosen = result!;
      expect(chosen.userId, 'sara@example.com');
      expect(chosen.id, 'e2');
    });

    testWidgets('marks the selected row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pick(tester,
          employees: [
            _person('e1', 'علی رضایی', userId: 'ali@example.com'),
            _person('e2', 'سارا محمدی', userId: 'sara@example.com'),
          ],
          selectedUserId: 'ali@example.com');
      final ali = find.widgetWithText(Card, 'علی رضایی');
      expect(
          find.descendant(
              of: ali,
              matching: find.byIcon(Icons.radio_button_checked_rounded)),
          findsOneWidget);
      final sara = find.widgetWithText(Card, 'سارا محمدی');
      expect(
          find.descendant(
              of: sara,
              matching: find.byIcon(Icons.radio_button_checked_rounded)),
          findsNothing);
    });

    testWidgets('shows the empty state when no one has an account',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pick(tester, employees: [
        _person('e1', 'علی رضایی'),
      ]);
      expect(find.text('هیچ پرسنلی حساب کاربری ندارد.'), findsOneWidget);
    });

    testWidgets('shows no-result when the search matches nothing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pick(tester, employees: [
        _person('e1', 'علی رضایی', userId: 'ali@example.com'),
      ]);
      await tester.enterText(find.byType(TextField), 'ناموجود');
      await tester.pumpAndSettle();
      expect(find.text('نتیجه‌ای پیدا نشد.'), findsOneWidget);
    });

    testWidgets('fits a 60-character name at 320 px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final longName = 'ا' * 60;
      await _pick(tester, employees: [
        _person('e1', longName, userId: 'long@example.com'),
      ]);
      expect(find.text(longName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
