import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/persian_format.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../domain/entities/request_models.dart';
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

/// Field rows of the printed «اطلاعات درخواست» table: the label and the text
/// the screen shows ([formatted], from `RequestDetailView.format`); a value
/// without a formatted text falls back to the generic formatting.
List<List<String>> requestPrintFields(
  Map<String, dynamic> values, {
  Map<String, String> labels = const {},
  Map<String, String> formatted = const {},
}) =>
    [
      for (final entry in values.entries)
        if (entry.value is! List ||
            (entry.value as List).isEmpty ||
            (entry.value as List).first is! Map)
          [
            persianDocumentFieldLabel(labels[entry.key] ?? entry.key),
            formatted[entry.key] ??
                (entry.value is List
                    ? (entry.value as List).join('، ')
                    : entry.value is bool
                        ? (entry.value == true ? 'بله' : 'خیر')
                        : isDurationMap(entry.value)
                            ? formatPersianDuration(entry.value)
                            : formatNumber(entry.value)),
          ],
    ];

/// «علت رد» / «علت بازگشت» rows of a request: the rejection reason and the
/// comment of a step that sent the request back for correction.
List<List<String>> requestPrintReasons(Map<String, dynamic> request) {
  final rejected = '${request['rejection_reason'] ?? ''}'.trim();
  return [
    if (rejected.isNotEmpty) ['علت رد', rejected],
    for (final stage in request['stages'] as List? ?? const [])
      if (stage is Map &&
          stage['status'] == 'returned' &&
          '${stage['comment'] ?? ''}'.trim().isNotEmpty)
        ['علت بازگشت', '${stage['comment']}'.trim()],
  ];
}

/// «وضعیت اجرا» rows of a request from `execution`; the raw error is never
/// printed. Empty when the request has no execution.
List<List<String>> requestPrintExecution(Map<String, dynamic> request) {
  final execution = RequestExecution.fromMap(request['execution']);
  if (!execution.applicable) return const [];
  return [
    ['وضعیت اجرا', execution.sentence],
    if (execution.succeeded && execution.reference.isNotEmpty)
      ['شماره سند اجرا', execution.reference],
  ];
}

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
  Map<String, String> formatted = const {},
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

  final fields =
      requestPrintFields(values, labels: labels, formatted: formatted);
  final reasons = requestPrintReasons(request);
  final execution = requestPrintExecution(request);

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
            for (final row in execution) info(row[0], row[1]),
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
      if (reasons.isNotEmpty) ...[
        title('علت رد یا بازگشت'),
        table(['عنوان', 'توضیح'], reasons),
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
          'توضیح',
          'تاریخ'
        ], [
          for (final activity in activities)
            [
              activity.stageTitle.isEmpty ? '—' : activity.stageTitle,
              activity.actorName.isNotEmpty
                  ? activity.actorName
                  : activity.actor.contains('@')
                      ? activity.actor
                      : persianRoleLabel(activity.actor),
              requestActionLabel(activity.action),
              activity.comment.trim().isEmpty ? '—' : activity.comment.trim(),
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
