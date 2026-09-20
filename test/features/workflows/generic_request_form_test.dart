import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/pages/generic_request_page.dart';
import 'package:asoud_erp/features/parties/presentation/pages/personnel_roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
class _Repository extends Mock implements GenericRequestRepository {}
void main() {
  testWidgets('switching request forms removes previous keys and supplies false checkbox', (tester) async {
    final repo = _Repository();
    when(() => repo.options()).thenAnswer((_) async => [
      {'name': 'one', 'workflow_title': 'First', 'fields': [{'key': 'old', 'label': 'Old value', 'type': 'Short Text'}]},
      {'name': 'two', 'workflow_title': 'Second', 'fields': [{'key': 'confirm', 'label': 'Confirm', 'type': 'Checkbox', 'required': true}]},
    ]);
    Map<String, dynamic>? saved;
    when(() => repo.create(any(), any())).thenAnswer((call) async { saved = Map.from(call.positionalArguments.first as Map); });
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light, home: GenericRequestPage(repository: repo)));
    await tester.pumpAndSettle();
    final page = tester.widget<AsoudFormPage>(find.byType(AsoudFormPage));
    for (final tile in tester.widgetList<ExpansionTile>(find.byType(ExpansionTile))) {
      // The canonical sections begin collapsed.
      expect(tile.initiallyExpanded, isFalse);
    }
    await tester.tap(find.byType(ExpansionTile).first); await tester.pumpAndSettle();
    tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>).first).onChanged!('one');
    await tester.pumpAndSettle();
    final old = tester.widget<TextFormField>(find.byKey(const ValueKey('one:old'), skipOffstage: false));
    old.controller!.text = 'stale';
    tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>).first).onChanged!('two');
    await tester.pumpAndSettle();
    final subject = tester.widgetList<AsoudFormField>(find.byType(AsoudFormField, skipOffstage: false)).first;
    subject.controller.text = 'Test request';
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(saved!['values'], {'confirm': false});
    expect(page.title, isNotEmpty);
  });
  testWidgets('role editor persists canonical roles with no unsupported matrix', (tester) async {
    Set<String>? saved;
    Map? matrix;
    await tester.pumpWidget(MaterialApp(theme: AsoudTheme.light, home: PersonnelRolesPage(
      initialValue: const {'حسابدار'}, onConfirm: (roles, access) async { saved = roles; matrix = access; })));
    tester.widget<AsoudFormPage>(find.byType(AsoudFormPage)).onSave();
    await tester.pumpAndSettle();
    expect(saved, {'accountant'}); expect(matrix, isEmpty);
  });
}
