import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_link_fields.dart';

void main() {
  group('T3: Leave type chooser localization', () {
    test('persianLeaveTypeLabel maps compound and raw leave type names', () {
      expect(persianLeaveTypeLabel('Casual Leave'), 'مرخصی اتفاقی');
      expect(persianLeaveTypeLabel('سالانه — Casual Leave'), 'مرخصی اتفاقی');
      expect(persianLeaveTypeLabel('Compensatory Off'), 'مرخصی جبرانی');
      expect(persianLeaveTypeLabel('سایر / Compensatory Off'), 'مرخصی جبرانی');
      expect(persianLeaveTypeLabel('Leave Without Pay'), 'مرخصی بدون حقوق');
      expect(persianLeaveTypeLabel('بدون حقوق / Leave Without Pay'),
          'مرخصی بدون حقوق');
      expect(persianLeaveTypeLabel('Privilege Leave'), 'مرخصی استحقاقی');
      expect(
          persianLeaveTypeLabel('سالانه — Privilege Leave'), 'مرخصی استحقاقی');
      expect(persianLeaveTypeLabel('Sick Leave'), 'مرخصی استعلاجی');
      expect(persianLeaveTypeLabel('استعلاجی — Sick Leave'), 'مرخصی استعلاجی');
    });

    testWidgets(
        'showRequestOptionPicker for leave type shows ONLY Persian titles',
        (tester) async {
      Map<String, dynamic>? selected;

      final rows = [
        {'value': 'Casual Leave', 'label': 'سالانه — Casual Leave'},
        {'value': 'Compensatory Off', 'label': 'سایر / Compensatory Off'},
        {'value': 'Leave Without Pay', 'label': 'بدون حقوق / Leave Without Pay'},
        {'value': 'Privilege Leave', 'label': 'سالانه — Privilege Leave'},
        {'value': 'Sick Leave', 'label': 'استعلاجی — Sick Leave'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showRequestOptionPicker(
                    context,
                    title: 'نوع مرخصی',
                    loader: (_) async => rows,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Must find ONLY Persian titles
      expect(find.text('مرخصی اتفاقی'), findsOneWidget);
      expect(find.text('مرخصی جبرانی'), findsOneWidget);
      expect(find.text('مرخصی بدون حقوق'), findsOneWidget);
      expect(find.text('مرخصی استحقاقی'), findsOneWidget);
      expect(find.text('مرخصی استعلاجی'), findsOneWidget);

      // Must NOT find English technical names
      expect(find.textContaining('Casual Leave'), findsNothing);
      expect(find.textContaining('Compensatory Off'), findsNothing);
      expect(find.textContaining('Leave Without Pay'), findsNothing);
      expect(find.textContaining('Privilege Leave'), findsNothing);
      expect(find.textContaining('Sick Leave'), findsNothing);

      // Tapping item returns the stored English value
      await tester.tap(find.text('مرخصی اتفاقی'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!['value'], 'Casual Leave');
    });
  });
}
