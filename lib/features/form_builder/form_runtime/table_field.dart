import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../form_repository.dart';
import 'rules_engine.dart';
import 'table_row_page.dart';

Widget? buildTableField({
  required FormMap f,
  required dynamic value,
  required String label,
  required bool editable,
  required bool snapshot,
  required FormRepository repository,
  required String? formName,
  required ValueChanged<dynamic> onChanged,
  BuildContext? context,
}) {
  if (f['type'] != 'Table') {
    return null;
  }

  return Builder(
    builder: (ctx) {
      final effectiveContext = context ?? ctx;
      final columns = formMaps(f['columns']);
      final rows = formMaps(value);

      final minRows = (f['min_rows'] as num?)?.toInt();
      final maxRows = (f['max_rows'] as num?)?.toInt();
      final reachedMax = maxRows != null && rows.length >= maxRows;
      final belowMin = minRows != null && rows.length < minRows;

      // Identify formula or amount column for row calculations and grand total
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

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AsoudColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    size: 20,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AsoudColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${toPersianDigits(rows.length)} ردیف · ${toPersianDigits(columns.length)} ستون',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AsoudColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Rows list
            if (rows.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AsoudColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AsoudColors.border),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'ردیفی ثبت نشده است. برای افزودن از دکمه زیر استفاده کنید.',
                  style: TextStyle(fontSize: 12, color: AsoudColors.muted),
                ),
              ),

            for (var i = 0; i < rows.length; i++) ...[
              _buildRowCard(
                context: effectiveContext,
                index: i,
                row: rows[i],
                columns: columns,
                formulaCol: formulaCol,
                editable: editable,
                repository: repository,
                formName: formName,
                tableLabel: label,
                onEdit: () async {
                  final updatedRow = await Navigator.push<FormMap>(
                    effectiveContext,
                    MaterialPageRoute(
                      builder: (_) => TableRowPage(
                        tableTitle: label,
                        columns: columns,
                        row: rows[i],
                        repository: repository,
                        formName: formName,
                        isNew: false,
                      ),
                    ),
                  );
                  if (updatedRow != null) {
                    final newRows = [...rows];
                    newRows[i] = updatedRow;
                    onChanged(newRows);
                  }
                },
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: effectiveContext,
                    builder: (c) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('حذف ردیف'),
                        content: Text(
                          'آیا از حذف ردیف ${toPersianDigits(i + 1)} اطمینان دارید؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('انصراف'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AsoudColors.danger,
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirmed == true) {
                    final newRows = [...rows]..removeAt(i);
                    onChanged(newRows);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],

            // Add Row button
            if (editable) ...[
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: reachedMax ? AsoudColors.border : const Color(0xFF1876D2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: reachedMax
                      ? null
                      : () async {
                          final newRow = await Navigator.push<FormMap>(
                            effectiveContext,
                            MaterialPageRoute(
                              builder: (_) => TableRowPage(
                                tableTitle: label,
                                columns: columns,
                                row: const {},
                                repository: repository,
                                formName: formName,
                                isNew: true,
                              ),
                            ),
                          );
                          if (newRow != null) {
                            onChanged([...rows, newRow]);
                          }
                        },
                  icon: Icon(
                    Icons.add,
                    size: 18,
                    color: reachedMax ? AsoudColors.muted : const Color(0xFF1876D2),
                  ),
                  label: Text(
                    'افزودن ردیف',
                    style: TextStyle(
                      color: reachedMax ? AsoudColors.muted : const Color(0xFF1876D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (reachedMax)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'حداکثر تعداد ردیف (${toPersianDigits(maxRows)}) تکمیل شده است.',
                    style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
                  ),
                ),
              if (belowMin)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'حداقل ${toPersianDigits(minRows)} ردیف باید ثبت شود.',
                    style: const TextStyle(fontSize: 11, color: AsoudColors.warning),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Grand Total Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF7EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC3E6CB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'جمع کل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B6B3A),
                    ),
                  ),
                  Text(
                    '${formatNumber(grandTotal)} تومان',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B6B3A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildRowCard({
  required BuildContext context,
  required int index,
  required FormMap row,
  required List<FormMap> columns,
  required FormMap? formulaCol,
  required bool editable,
  required FormRepository repository,
  required String? formName,
  required String tableLabel,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final firstCol = columns.isNotEmpty ? columns.first : null;
  String rowTitle;
  if (firstCol != null && row[firstCol['key']] != null && '${row[firstCol['key']]}'.trim().isNotEmpty) {
    rowTitle = '${row[firstCol['key']]}';
  } else {
    rowTitle = firstCol != null ? '${firstCol['label'] ?? 'نام'}' : 'ردیف';
  }

  // Build details line from other columns
  final detailParts = <String>[];
  for (final col in columns) {
    if (col == firstCol || col == formulaCol) continue;
    final val = row[col['key']];
    final displayVal = val != null && '$val'.isNotEmpty
        ? formatNumber(val)
        : '۰';
    detailParts.add('${col['label']}: $displayVal');
  }

  final rowCalculationValue = formulaCol != null ? formNumber(row[formulaCol['key']]) : null;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Actions row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${toPersianDigits(index + 1)}. $rowTitle',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AsoudColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (editable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    color: const Color(0xFF1876D2),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(4),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19),
                    color: const Color(0xFFE53935),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(4),
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),

        // Sub details line
        if (detailParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detailParts.join(' · '),
            style: const TextStyle(
              fontSize: 12,
              color: AsoudColors.muted,
            ),
          ),
        ],

        // Row calculated sub-box
        if (formulaCol != null && rowCalculationValue != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF7EE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formulaCol['label'] ?? 'مبلغ ردیف'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${formatNumber(rowCalculationValue)} تومان',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B6B3A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
