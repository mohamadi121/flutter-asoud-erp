import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_templates/presentation/widgets/detail_info_card.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';

void main() {
  group('T4: Clipped Persian text and email LTR isolation on detail screens',
      () {
    for (final width in [320.0, 390.0]) {
      testWidgets(
          'TemplateInfoCard wraps long labels, isolates emails, and adds Tooltips at ${width.toInt()} px',
          (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const email = 'hr-manager@asoud-demo.local';
        final rows = [
          const InfoRowData(
              Icons.receipt_long_rounded, 'سند مربوطه', 'REQ-00021'),
          const InfoRowData(Icons.email_outlined, 'مسئول درخواست', email),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AsoudTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TemplateInfoCard(
                    title: 'اطلاعات درخواست',
                    rows: rows,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Label tooltip
        final labelTooltip = find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'سند مربوطه',
        );
        expect(labelTooltip, findsOneWidget);

        // Email with LTR isolate and tooltip
        final emailWithIsolate = find.textContaining(
          '${String.fromCharCode(0x2066)}$email${String.fromCharCode(0x2069)}',
        );
        expect(emailWithIsolate, findsOneWidget);

        final emailTooltip = find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message?.contains(email) ?? false),
        );
        expect(emailTooltip, findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'RequestInfoRow wraps long labels, isolates emails, and adds Tooltips at ${width.toInt()} px',
          (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const email = 'hr-manager@asoud-demo.local';

        await tester.pumpWidget(
          MaterialApp(
            theme: AsoudTheme.light,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Column(
                  children: [
                    RequestInfoRow('سند مربوطه', 'REQ-00021'),
                    RequestInfoRow('مسئول درخواست', email),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final labelTooltip = find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'سند مربوطه',
        );
        expect(labelTooltip, findsOneWidget);

        final emailWithIsolate = find.textContaining(
          '${String.fromCharCode(0x2066)}$email${String.fromCharCode(0x2069)}',
        );
        expect(emailWithIsolate, findsOneWidget);

        final emailTooltip = find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message?.contains(email) ?? false),
        );
        expect(emailTooltip, findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
