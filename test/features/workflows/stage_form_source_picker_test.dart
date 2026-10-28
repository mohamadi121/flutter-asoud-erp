import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_form_source_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {}
class _Forms extends FormRepository {
  _Forms() : super(_Client(), 'دفتر آزمون');
  final calls = <String>[];
  @override
  Future<List<FormMap>> list(String kind, {bool manage = true}) async => kind == 'Request'
    ? [{'name': 'leave', 'title': 'درخواست مرخصی', 'status': 'Published', 'module_key': 'HR', 'active_revision': 'revision-1'},
       {'name': 'draft', 'title': 'فرم منتشرنشده', 'status': 'Draft', 'module_key': 'HR'}]
    : [{'name': 'document', 'title': 'سند نمونه', 'status': 'Published', 'module_key': 'Finance', 'active_revision': 'revision-1'}];
  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async {
    calls.add(method);
    expect(method, 'get_form');
    expect(data['manage'], 1);
    expect(data['revision_name'], 'revision-1');
    return {
    'name': data['name'], 'revision': 'revision-1', 'submission_source_version': 1,
    'active_revision': 'revision-1', 'disabled': false,
    'schema': {'title': data['name'] == 'leave' ? 'درخواست مرخصی' : 'سند نمونه',
      'kind': data['name'] == 'leave' ? 'Request' : 'Document'},
    };
  }
}

Future<void> _reveal(WidgetTester tester, Finder target, {bool interactive = true}) async {
  final scrollable = find.descendant(
      of: find.byKey(const ValueKey('stage-source-list')),
      matching: find.byType(Scrollable)).first;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 160, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target, findsOneWidget);
  expect(tester.getRect(target).overlaps(
      tester.getRect(find.byKey(const ValueKey('stage-source-list')))), isTrue);
  if (interactive) expect(target.hitTestable(), findsOneWidget);
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('source drawer selects a published request without creating an entry at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? selected;
      final repository = _Forms();
      await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light,
        builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () async {
          selected = await showModalBottomSheet<Map<String, dynamic>>(context: context,
            isScrollControlled: true, showDragHandle: true, useSafeArea: true,
            builder: (_) => StageFormSourcePicker(repository: repository));
        }, child: const Text('باز کردن'))))));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(find.text('درخواست‌ها'), findsOneWidget);
      expect(find.text('سندها'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'انتخاب و تأیید');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      final draft = find.byKey(const ValueKey('stage-source-draft'));
      await _reveal(tester, draft, interactive: false);
      expect(tester.widget<ListTile>(draft).enabled, isFalse);
      expect(tester.widget<ListTile>(draft).onTap, isNull);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(repository.calls, isEmpty);
      final row = find.byKey(const ValueKey('stage-source-leave'));
      await _reveal(tester, row);
      await tester.tap(row.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(selected, {'form': 'leave', 'revision': 'revision-1', 'title': 'درخواست مرخصی', 'kind': 'Request'});
      expect(repository.calls, ['get_form']);
      expect(find.text('انتخاب درخواست یا سند'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
