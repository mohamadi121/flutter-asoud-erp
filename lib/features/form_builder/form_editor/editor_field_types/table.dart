import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../editor_widgets.dart';

typedef EditColumnCallback = Future<FormMap?> Function(
  BuildContext context,
  FormMap subSchema,
  FormMap original, {
  bool column,
  String? parentNative,
});

List<Widget> buildTableConfig({
  required BuildContext context,
  required FormMap f,
  required FormMap schema,
  required void Function(String key, dynamic value) set,
  required EditColumnCallback onEditColumn,
}) {
  if (f['type'] != 'Table') {
    return const [];
  }

  void handleNumeric(String key, dynamic value) {
    if (value == null) {
      f.remove(key);
    } else {
      set(key, value);
    }
  }

  final columns = formMaps(f['columns']);

  return [
    const Text(
      'جدول ایجادشده در تب پایه',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            f['orientation'] == 'vertical'
                ? Icons.view_column_outlined
                : Icons.table_rows_outlined,
            color: const Color(0xFF5B6478),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              f['orientation'] == 'vertical'
                  ? 'جدول عمودی · تکرار ستون\nجهت نمایش در تب پایه تعیین شده است'
                  : 'جدول افقی · تکرار ردیف\nجهت نمایش در تب پایه تعیین شده است',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Icon(Icons.lock_outline, size: 18),
        ],
      ),
    ),
    const SizedBox(height: 14),
    Text(
      'مشخصه‌های جدول · ${columns.length}',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 6),
    for (var i = 0; i < columns.length; i++)
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          border: Border.all(color: const Color(0xFFE2E8F2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
        leading: Icon(_columnIcon('${columns[i]['type'] ?? 'Text'}'), color: const Color(0xFF1876D2)),
        title: Text('${columns[i]['label']}'),
        subtitle: Text('${_columnTypeLabel('${columns[i]['type'] ?? 'Text'}')} · ${columns[i]['required'] == true ? 'اجباری' : 'اختیاری'}'),
        onTap: () async {
          final result = await onEditColumn(
            context,
            {
              'workflow_fields': formMaps(schema['workflow_fields'])
                      .where((t) => t['key'] == f['workflow_key'])
                      .firstOrNull?['columns'] ??
                  [],
              'sections': [
                {'fields': f['columns']},
              ],
            },
            columns[i],
            column: true,
            parentNative: f['native_key'] as String?,
          );
          if (result != null && context.mounted) {
            final cols = formMaps(f['columns']);
            cols[i] = result;
            set('columns', cols);
          }
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'جابه‌جایی به بالا',
              onPressed: i == 0 ? null : () {
                final cols = formMaps(f['columns']);
                cols.insert(i - 1, cols.removeAt(i));
                set('columns', cols);
              },
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'جابه‌جایی به پایین',
              onPressed: i == columns.length - 1 ? null : () {
                final cols = formMaps(f['columns']);
                cols.insert(i + 1, cols.removeAt(i));
                set('columns', cols);
              },
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'حذف مشخصه',
              onPressed: () async {
                if (!await formConfirm(context, 'مشخصه حذف شود؟') || !context.mounted) return;
                final cols = formMaps(f['columns'])..removeAt(i);
                set('columns', cols);
              },
              icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
            ),
          ],
        ),
          ),
        ),
      ),
    FilledButton.icon(
      onPressed: () async {
        final result = await onEditColumn(
          context,
          {
            'workflow_fields': formMaps(schema['workflow_fields'])
                    .where((t) => t['key'] == f['workflow_key'])
                    .firstOrNull?['columns'] ??
                [],
            'sections': [
              {'fields': f['columns']},
            ],
          },
          {'key': 'c_${newFormId()}', 'label': '', 'type': 'Text'},
          column: true,
          parentNative: f['native_key'] as String?,
        );
        if (result != null && context.mounted) {
          set('columns', [...formMaps(f['columns']), result]);
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('افزودن مشخصه جدید'),
    ),
    editorFieldText(
      label: 'حداقل ردیف',
      value: f['min_rows'],
      numeric: true,
      onChanged: (v) => handleNumeric('min_rows', v),
    ),
    editorFieldText(
      label: 'حداکثر ردیف (تا ۱۰۰)',
      value: f['max_rows'],
      numeric: true,
      onChanged: (v) => handleNumeric('max_rows', v),
    ),
  ];
}

IconData _columnIcon(String type) => switch (type) {
      'LongText' => Icons.segment_outlined,
      'Integer' || 'Decimal' => Icons.tag_outlined,
      'Money' => Icons.payments_outlined,
      'Date' => Icons.calendar_today_outlined,
      'Time' => Icons.access_time_outlined,
      'Select' => Icons.arrow_drop_down_circle_outlined,
      'Checkbox' => Icons.checklist_outlined,
      'Formula' => Icons.calculate_outlined,
      'File' => Icons.attach_file_outlined,
      _ => Icons.title_outlined,
    };

String _columnTypeLabel(String type) => switch (type) {
      'LongText' => 'متن بلند',
      'Integer' || 'Decimal' => 'عدد',
      'Money' => 'مبلغ',
      'Date' => 'تاریخ',
      'Time' => 'ساعت',
      'Select' => 'فهرست انتخابی',
      'Checkbox' => 'چک‌لیست',
      'Formula' => 'محاسباتی',
      'File' => 'پیوست هر رکورد',
      _ => 'متن کوتاه',
    };
