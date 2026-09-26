import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/jalali_date.dart';
import '../../domain/entities/workflow_task.dart';

/// Persian labels of workflow activity actions, shared by screen and print.
String requestActionLabel(String action) => switch (action) {
      'Complete' => 'ثبت و تکمیل',
      'Approve' => 'تأیید',
      'Reject' => 'رد',
      'Return' => 'بازگشت برای اصلاح',
      'Cancelled' => 'لغو درخواست',
      'Edited' => 'ویرایش درخواست',
      'System Action Succeeded' => 'اقدام خودکار',
      'System Action Failed' => 'خطای اقدام خودکار',
      'Condition True' || 'Condition False' => 'بررسی شرط',
      _ => action,
    };

/// Item rows stored in a request's Item Table values.
List<Map<String, dynamic>> requestItemRows(Map<String, dynamic> values) => [
      for (final value in values.values)
        if (value is List)
          for (final row in value)
            if (row is Map && row['item_code'] != null)
              Map<String, dynamic>.from(row),
    ];

/// The PDF fonts have no glyph for the zero-width non-joiner (نیم‌فاصله).
String _p(Object? value) => '${value ?? ''}'.replaceAll('\u200c', ' ');

String _number(Object? value) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return '${value ?? ''}';
  return toPersianDigits(
      number == number.roundToDouble() ? number.toInt() : number);
}

/// A4 print of a generic request: header, QR code, fields, items,
/// attachments and the approval trail.
Future<Uint8List> buildRequestPdf({
  required Map<String, dynamic> request,
  required List<WorkflowTaskActivity> activities,
  Map<String, String> labels = const {},
  String statusLabel = '',
}) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
  final doc =
      pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final values = Map<String, dynamic>.from(request['values'] as Map? ?? {});
  final items = requestItemRows(values);
  final number = '${request['name'] ?? ''}';
  final grey = PdfColor.fromHex('#71809B');
  final line = PdfColor.fromHex('#E2E8F2');

  pw.Widget info(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 90,
              child: pw.Text(_p(label),
                  style: pw.TextStyle(color: grey, fontSize: 9))),
          pw.Expanded(
              child: pw.Text(value.isEmpty ? '—' : _p(value),
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers.map(_p).toList(),
        data: [for (final row in rows) row.map(_p).toList()],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5FB')),
        border: pw.TableBorder.all(color: line, width: .6),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
      );

  pw.Widget title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_p(text),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      );

  final fields = [
    for (final entry in values.entries)
      if (entry.value is! List ||
          (entry.value as List).isEmpty ||
          (entry.value as List).first is! Map)
        [
          labels[entry.key] ?? entry.key,
          entry.value is List
              ? (entry.value as List).join('، ')
              : entry.value is bool
                  ? (entry.value == true ? 'بله' : 'خیر')
                  : '${entry.value ?? '—'}',
        ],
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(32),
    build: (context) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_p(request['company']),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Text(_p(request['request_type'] ?? 'درخواست'),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ]),
        ),
        pw.Text('ASOUD ERP',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                color: PdfColor.fromHex('#1769F6'))),
      ]),
      pw.SizedBox(height: 12),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(children: [
            info('شماره درخواست', number),
            info('تاریخ ثبت', formatJalaliIso('${request['creation'] ?? ''}')),
            info('وضعیت', statusLabel),
            info('درخواست‌کننده', '${request['requester_name'] ?? ''}'),
            info('واحد', '${request['department'] ?? ''}'),
            info('عنوان', '${request['subject'] ?? ''}'),
          ]),
        ),
        pw.SizedBox(width: 12),
        if (number.isNotEmpty)
          pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: number,
              width: 72,
              height: 72),
      ]),
      if (fields.isNotEmpty) ...[
        title('اطلاعات درخواست'),
        table(['عنوان', 'مقدار'], fields),
      ],
      if (items.isNotEmpty) ...[
        title('اقلام درخواست'),
        table([
          'ردیف',
          'کالا',
          'تعداد',
          'واحد'
        ], [
          for (final (index, row) in items.indexed)
            [
              toPersianDigits(index + 1),
              '${row['item_name'] ?? row['item_code']}',
              _number(row['qty']),
              '${row['uom'] ?? ''}',
            ]
        ]),
      ],
      if ((request['attachments'] as List? ?? const []).isNotEmpty) ...[
        title('پیوست‌ها'),
        for (final (index, file) in (request['attachments'] as List).indexed)
          pw.Text(
              _p('${toPersianDigits(index + 1)}. ${(file as Map)['filename']}'),
              style: const pw.TextStyle(fontSize: 9)),
      ],
      if (activities.isNotEmpty) ...[
        title('گردش تأیید'),
        table([
          'مرحله',
          'اقدام‌کننده',
          'اقدام',
          'تاریخ'
        ], [
          for (final activity in activities)
            [
              activity.stageTitle.isEmpty ? '—' : activity.stageTitle,
              activity.actor,
              requestActionLabel(activity.action),
              activity.createdOn == null
                  ? '—'
                  : formatJalaliIso(activity.createdOn!.toIso8601String()),
            ]
        ]),
      ],
    ],
  ));
  return doc.save();
}
