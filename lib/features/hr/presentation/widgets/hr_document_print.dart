import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/failure_message.dart';

Future<Uint8List> convertHrDocument(String html, {PdfPageFormat format = PdfPageFormat.a4}) async {
  if (html.trim().isEmpty) {
    throw const FormatException('خروجی چاپ موجود نیست. سند را دوباره دریافت کنید.');
  }
  // printing 5.14.3 has no replacement for converting server-rendered HTML.
  // Its suggested PDF creation APIs would rebuild the document on the client
  // and lose the authoritative letterhead, snapshot and draft watermark.
  // ignore: deprecated_member_use
  return Printing.convertHtml(html: html, format: format);
}

Future<void> printHrDocument(String html) async {
  final bytes = await convertHrDocument(html);
  await Printing.layoutPdf(onLayout: (_) async => bytes, format: PdfPageFormat.a4);
}

class HrDocumentPrintButton extends StatefulWidget {
  const HrDocumentPrintButton({required this.loadHtml, this.label = 'چاپ یا ذخیره PDF', super.key});

  final Future<String> Function() loadHtml;
  final String label;

  @override
  State<HrDocumentPrintButton> createState() => _HrDocumentPrintButtonState();
}

class _HrDocumentPrintButtonState extends State<HrDocumentPrintButton> {
  bool _running = false;

  Future<void> _print() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final html = await widget.loadHtml();
      if (!mounted) return;
      if (html.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('خروجی چاپ موجود نیست. سند را دوباره دریافت کنید.'),
        ));
        return;
      }
      await printHrDocument(html);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('چاپ سند انجام نشد. ${failureMessage(error)}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _running ? null : _print,
    icon: const Icon(Icons.print_outlined),
    label: Text(_running ? 'در حال آماده‌سازی چاپ' : widget.label),
  );
}
