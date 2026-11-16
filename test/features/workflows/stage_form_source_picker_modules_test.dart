import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_form_source_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {}

/// Returns one request per module so the picker can be filtered by chip.
class _Forms extends FormRepository {
  _Forms() : super(_Client(), 'دفتر آزمون');
  @override
  Future<List<FormMap>> list(String kind, {bool manage = true}) async =>
      kind == 'Request'
          ? [
              {'name': 'sell', 'title': 'درخواست فروش', 'status': 'Published',
                  'module_key': 'Selling', 'active_revision': 'revision-1'},
              {'name': 'fin', 'title': 'درخواست مالی', 'status': 'Published',
                  'module_key': 'Finance', 'active_revision': 'revision-1'},
            ]
          : <FormMap>[];
  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async =>
      throw StateError('not used in this test');
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.descendant(
      of: find.byKey(const ValueKey('stage-source-list')),
      matching: find.byType(Scrollable)).first;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 160, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target, findsOneWidget);
}

Future<void> _open(WidgetTester tester, {String initialModule = ''}) async {
  await tester.pumpWidget(MaterialApp(
      theme: AsoudTheme.light,
      builder: (_, child) => Directionality(
          textDirection: TextDirection.rtl, child: child!),
      home: Builder(builder: (context) => Scaffold(
          body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  useSafeArea: true,
                  builder: (_) => StageFormSourcePicker(
                      repository: _Forms(), initialModule: initialModule)),
              child: const Text('باز کردن'))))));
  await tester.tap(find.text('باز کردن'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('module picker uses canonical keys and labels at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester);

      // The canonical Persian labels are shown, not the legacy ones.
      expect(find.text('خدمات اداری'), findsOneWidget);
      expect(find.text('انبار'), findsOneWidget);
      expect(find.text('فروش'), findsOneWidget);
      expect(find.text('خرید'), findsOneWidget);
      // The legacy «اداری» label for Admin is gone.
      expect(find.text('اداری'), findsNothing);

      // A form stored under the canonical 'Selling' key is grouped under the
      // فروش chip.
      await tester.tap(find.text('فروش'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const ValueKey('stage-source-sell')));
      expect(find.byKey(const ValueKey('stage-source-fin')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a legacy initial module resolves to its canonical chip',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester, initialModule: 'Accounting');

    // 'Accounting' resolves to the Finance module, so only the مالی form shows.
    await _reveal(tester, find.byKey(const ValueKey('stage-source-fin')));
    expect(find.byKey(const ValueKey('stage-source-sell')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
