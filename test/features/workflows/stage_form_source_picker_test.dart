import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/form_builder/form_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/stage_form_source_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements FrappeApiClient {}
class _Forms extends FormRepository {
  _Forms() : super(_Client(), 'دفتر آزمون');
  @override
  Future<List<FormMap>> list(String kind, {bool manage = true}) async => kind == 'Request'
    ? [{'name': 'leave', 'title': 'درخواست مرخصی', 'status': 'Published', 'module_key': 'HR', 'active_revision': 'revision-1'},
       {'name': 'draft', 'title': 'فرم منتشرنشده', 'status': 'Draft', 'module_key': 'HR'}]
    : [{'name': 'document', 'title': 'سند نمونه', 'status': 'Published', 'module_key': 'Finance', 'active_revision': 'revision-1'}];
  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async => {
    'name': data['name'], 'revision': 'revision-1', 'submission_source_version': 1,
    'active_revision': 'revision-1', 'disabled': false,
    'schema': {'title': data['name'] == 'leave' ? 'درخواست مرخصی' : 'سند نمونه',
      'kind': data['name'] == 'leave' ? 'Request' : 'Document'},
  };
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('source drawer selects a published request without creating an entry at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? selected;
      await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light, home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () async {
          selected = await showModalBottomSheet<Map<String, dynamic>>(context: context,
            isScrollControlled: true, showDragHandle: true, useSafeArea: true,
            builder: (_) => StageFormSourcePicker(repository: _Forms()));
        }, child: const Text('باز کردن'))))));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(find.text('درخواست‌ها'), findsOneWidget);
      expect(find.text('سندها'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'انتخاب و تأیید');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(tester.widget<ListTile>(find.byKey(const ValueKey('stage-source-draft'))).enabled, isFalse);
      final row = find.byKey(const ValueKey('stage-source-leave'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(selected, {'form': 'leave', 'revision': 'revision-1', 'title': 'درخواست مرخصی', 'kind': 'Request'});
      expect(find.text('انتخاب درخواست یا سند'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
