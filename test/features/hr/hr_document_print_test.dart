import 'dart:async';
import 'dart:typed_data';

import 'package:asoud_erp/features/hr/presentation/widgets/hr_document_print.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// ignore: implementation_imports
import 'package:printing/src/interface.dart';

class _Printer extends PrintingPlatform {
  String? html;
  int layouts = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Uint8List> convertHtml(String html, String? baseUrl, PdfPageFormat format) async {
    this.html = html;
    return Uint8List.fromList([37, 80, 68, 70]);
  }

  @override
  Future<bool> layoutPdf(Printer? printer, LayoutCallback onLayout, String name,
      PdfPageFormat format, bool dynamicLayout, bool usePrinterSettings,
      OutputType outputType, bool forceCustomPrintPaper) async {
    expect(await onLayout(format), [37, 80, 68, 70]);
    layouts++;
    return true;
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('server HTML prints once and preserves draft banner at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final old = PrintingPlatform.instance;
      final printer = _Printer();
      PrintingPlatform.instance = printer;
      addTearDown(() => PrintingPlatform.instance = old);
      final response = Completer<String>();
      var calls = 0;
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: HrDocumentPrintButton(loadHtml: () {
          calls++;
          return response.future;
        })),
      )));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
      expect(calls, 1);
      const html = '<html dir="rtl"><body>پیش‌نمایش ـ فاقد اعتبار</body></html>';
      response.complete(html);
      await tester.pumpAndSettle();
      expect(printer.html, html);
      expect(printer.layouts, 1);
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed or empty output permits retry at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: HrDocumentPrintButton(loadHtml: () async {
          calls++;
          if (calls == 1) throw TimeoutException('');
          return '';
        })),
      )));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('چاپ سند انجام نشد.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('خروجی چاپ موجود نیست. سند را دوباره دریافت کنید.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNotNull);
    });
  }
}
