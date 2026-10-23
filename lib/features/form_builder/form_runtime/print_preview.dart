import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../form_repository.dart';
import 'formula_engine.dart';
import 'section_colors.dart';
import 'rules_engine.dart';

class FormPrintPreviewPage extends StatefulWidget {
  const FormPrintPreviewPage({
    required this.schema,
    required this.values,
    required this.repository,
    this.formName,
    super.key,
  });

  final FormMap schema;
  final FormMap values;
  final FormRepository repository;
  final String? formName;

  @override
  State<FormPrintPreviewPage> createState() => _FormPrintPreviewPageState();
}

class _FormPrintPreviewPageState extends State<FormPrintPreviewPage> {
  bool _isLandscape = false;

  @override
  Widget build(BuildContext context) {
    final computed = evaluatedValues(widget.schema, widget.values);
    final companyName = widget.repository.company.isNotEmpty
        ? widget.repository.company
        : 'شرکت نمونه آسود';
    final formTitle = '${widget.schema['title'] ?? 'فرم بدون عنوان'}';
    final moduleName = '${widget.schema['module'] ?? 'عمومی'}';
    final today = JalaliDate.fromDateTime(DateTime.now()).format();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F4F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AsoudColors.text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'پیش‌نمایش چاپ فرم',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AsoudColors.text,
            ),
          ),
          actions: [
            // Orientation Toggle Button
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: AsoudColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AsoudColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _orientationChip(
                    label: 'عمودی',
                    icon: Icons.portrait,
                    selected: !_isLandscape,
                    onTap: () => setState(() => _isLandscape = false),
                  ),
                  _orientationChip(
                    label: 'افقی',
                    icon: Icons.landscape,
                    selected: _isLandscape,
                    onTap: () => setState(() => _isLandscape = true),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'چاپ سند',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'سند آزمایشی آماده ارسال به چاپگر است (در پیش‌نمایش چاپ شدنی است).',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: _isLandscape ? 850 : 600,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Company Header & Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AsoudColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'واحد سازمانی: $moduleName',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AsoudColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              formTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF122044),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF3FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBED8FB)),
                              ),
                              child: const Text(
                                'نسخه آزمایشی / پیش‌نویس',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1876D2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Meta details box
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاریخ: $today',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AsoudColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'شماره: آزمایشی',
                              style: TextStyle(
                                fontSize: 10,
                                color: AsoudColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFD1D5DB), thickness: 1.5),
                  const SizedBox(height: 14),

                  // Sections
                  for (final section in formMaps(widget.schema['sections'])) ...[
                    _buildPrintSection(
                      context: context,
                      section: section,
                      computed: computed,
                      isLandscape: _isLandscape,
                    ),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 18),

                  // Signatures and Approvals section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تأییدیه‌ها و امضاها',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AsoudColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSignatureBox('متقاضی / درخواست‌کننده'),
                            const SizedBox(width: 10),
                            _buildSignatureBox('مدیر واحد مربوطه'),
                            const SizedBox(width: 10),
                            _buildSignatureBox('امور مالی و اداری'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Document Footer
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'این برگه در محیط پیش‌نمایش فرم‌ساز آسود تولید شده و فاقد اعتبار مالیاتی و حقوقی است.',
                          style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'صفحه ۱ از ۱',
                        style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orientationChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xFF1876D2) : AsoudColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? const Color(0xFF1876D2) : AsoudColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintSection({
    required BuildContext context,
    required FormMap section,
    required FormMap computed,
    required bool isLandscape,
  }) {
    final fields = formMaps(section['fields']);
    final sectionColor = sectionColors(section)?.background ?? const Color(0xFFF3F4F6);
    final nonTableFields = fields.where((f) => f['type'] != 'Table').toList();
    final tableFields = fields.where((f) => f['type'] == 'Table').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sectionColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${section['title'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            if ('${section['description'] ?? ''}'.trim().isNotEmpty)
              Text('${section['description']}', style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
          ]),
        ),
        const SizedBox(height: 8),

        // Non-table fields in printable 2-column key-value grid
        if (nonTableFields.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final f in nonTableFields)
                SizedBox(
                  width: isLandscape ? 380 : 260,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f['label']}: ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatFieldValue(f, computed['${f['key']}']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AsoudColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Repeating Tables
        for (final table in tableFields) ...[
          _buildPrintTable(table, computed['${table['key']}']),
          const SizedBox(height: 10),
        ],
      ],
    );
  }


  Widget _buildPrintTable(FormMap table, dynamic value) {
    final columns = formMaps(table['columns']);
    final rows = formMaps(value);

    // Calculate grand total if any column is formula or money
    FormMap? formulaCol;
    for (final col in columns) {
      if (col['type'] == 'Formula') {
        formulaCol = col;
        break;
      }
    }
    formulaCol ??= columns.cast<FormMap?>().firstWhere(
          (c) => c != null && (c['type'] == 'Money' || '${c['key']}'.contains('amount')),
          orElse: () => null,
        );

    var grandTotal = 0.0;
    if (formulaCol != null) {
      for (final r in rows) {
        grandTotal += formNumber(r[formulaCol['key']]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${table['label']}:',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(
            color: const Color(0xFFD1D5DB),
            width: 1,
          ),
          columnWidths: {
            0: const FixedColumnWidth(44),
            for (var i = 0; i < columns.length; i++) i + 1: const FlexColumnWidth(),
          },
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
              children: [
                const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'ردیف',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                for (final col in columns)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${col['label']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
              ],
            ),

            // Data Rows
            if (rows.isEmpty)
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('—', textAlign: TextAlign.center),
                  ),
                  for (var i = 0; i < columns.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        i == 0 ? 'ردیفی ثبت نشده است' : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AsoudColors.muted,
                        ),
                      ),
                    ),
                ],
              )
            else
              for (var rIdx = 0; rIdx < rows.length; rIdx++)
                TableRow(
                  decoration: BoxDecoration(
                    color: rIdx.isEven ? Colors.white : const Color(0xFFF9FAFB),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        toPersianDigits(rIdx + 1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    for (final col in columns)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          _formatColumnValue(col, rows[rIdx][col['key']]),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),

            // Footer / Total Row
            if (formulaCol != null)
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFEBF7EE)),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(''),
                  ),
                  for (var cIdx = 0; cIdx < columns.length; cIdx++)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        cIdx == 0
                            ? 'جمع کل:'
                            : (columns[cIdx] == formulaCol
                                ? '${formatNumber(grandTotal)} تومان'
                                : ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B6B3A),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignatureBox(String roleTitle) {
    return Expanded(
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
            style: BorderStyle.solid,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              roleTitle,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'امضا:',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                ),
                Text(
                  'تاریخ:',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFieldValue(FormMap field, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    final type = '${field['type']}';
    if (['Integer', 'Decimal', 'Money'].contains(type)) {
      final formatted = formatNumber(value);
      return type == 'Money' ? '$formatted تومان' : formatted;
    }
    if (type == 'Date' || type == 'DateTime') {
      return formatJalaliDateTimeIso('$value');
    }
    if (type == 'Boolean' || type == 'Checkbox') {
      return value == true ? 'بله' : 'خیر';
    }
    return '$value';
  }

  String _formatColumnValue(FormMap col, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    final type = '${col['type']}';
    if (['Integer', 'Decimal', 'Money', 'Formula'].contains(type)) {
      final numVal = double.tryParse(toLatinDigits('$value'));
      final formatted = numVal != null
          ? (numVal == numVal.truncateToDouble()
              ? formatNumber(numVal.toInt())
              : formatNumber(numVal))
          : formatNumber(value);
      return (type == 'Money' || col['label']?.toString().contains('مبلغ') == true)
          ? '$formatted تومان'
          : formatted;
    }
    return '$value';
  }
}
