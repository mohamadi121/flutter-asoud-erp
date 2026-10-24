import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_custom_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('جدول مرحله ردیف‌های درخواست را در عرض $width قفل می‌کند',
        (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final changes = <List<Map<String, dynamic>>>[];
      const field = WorkflowFormFieldDefinition(
        key: 'approved_items',
        label: 'اقلام مصوب',
        type: 'Table',
        rowsFromRequest: 'items',
        columns: [
          WorkflowFormFieldDefinition(
              key: 'quantity', label: 'تعداد درخواستی', type: 'Number', readonly: true),
          WorkflowFormFieldDefinition(
              key: 'approved', label: 'تعداد مصوب', type: 'Number', maxFromRow: 'quantity'),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(body: SingleChildScrollView(child: RequestCustomTable(
          field: field,
          initialValue: const [{'quantity': 2, 'approved': 1}],
          onChanged: changes.add,
        ))),
      ));
      expect(find.text('افزودن ردیف'), findsNothing);
      expect(find.byTooltip('حذف ردیف'), findsOneWidget);
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields, hasLength(2));
      expect(fields.first.enabled, isFalse);
      expect(fields.last.enabled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
