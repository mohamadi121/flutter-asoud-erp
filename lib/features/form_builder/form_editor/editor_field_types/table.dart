import 'package:flutter/material.dart';

import '../../../../core/utils/persian_format.dart';
import '../../form_repository.dart';
import '../../form_runtime.dart';
import '../editor_widgets.dart';
import '../field_sheet/advanced/computed/advanced_field_library_cards.dart';

typedef EditColumnCallback = Future<FormMap?> Function(
  BuildContext context,
  FormMap subSchema,
  FormMap original, {
  bool column,
  String? parentNative,
});

Widget buildTableAdvancedTab({
  required BuildContext context,
  required FormMap f,
  required FormMap schema,
  required void Function(String key, dynamic value) set,
  required EditColumnCallback onEditColumn,
  required ValueChanged<String> onSelectType,
}) {
  final columns = formMaps(f['columns']);
  final allTables = <FormMap>[
    for (final field in schemaFields(schema))
      if (field['type'] == 'Table') field,
  ];
  if (!allTables.any((t) => t['key'] == f['key'])) {
    allTables.insert(0, f);
  }

  final isVertical = f['orientation'] == 'vertical';
  final currentTableKey = '${f['key']}';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdvancedFieldLibraryCards(
        selectedType: 'Table',
        onSelectType: onSelectType,
        showTitle: false,
        compact: true,
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0DD),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F2)),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    color: Color(0xFFE67E22),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'ساختار جدول تکرارشونده',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF122044),
                        ),
                      ),
                      Text(
                        'تنظیمات پیشرفته · مشخصه‌های داخلی',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF5B6478),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'جدول ایجادشده در تب پایه',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF122044),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: allTables.any((t) => t['key'] == currentTableKey)
                      ? currentTableKey
                      : (allTables.isNotEmpty ? '${allTables.first['key']}' : null),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF5B6478),
                    size: 18,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    color: Color(0xFF122044),
                  ),
                  items: [
                    for (final t in allTables)
                      DropdownMenuItem(
                        value: '${t['key']}',
                        child: Text(
                          '${t['label']}'.isNotEmpty
                              ? '${t['label']}'
                              : '${t['key']}',
                        ),
                      ),
                  ],
                  onChanged: (selectedKey) {
                    if (selectedKey == null || selectedKey == currentTableKey) {
                      return;
                    }
                    final target =
                        allTables.firstWhere((t) => t['key'] == selectedKey);
                    set('key', target['key']);
                    set('label', target['label']);
                    set('orientation', target['orientation'] ?? 'horizontal');
                    set('columns', target['columns'] ?? []);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0ECFC),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      isVertical
                          ? Icons.view_column_outlined
                          : Icons.table_rows_outlined,
                      color: const Color(0xFF1876D2),
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVertical ? 'عمودی · افزودن ستون' : 'افقی · افزودن ردیف',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF122044),
                          ),
                        ),
                        const Text(
                          'جهت نمایش در تب پایه تعیین شده است',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF5B6478),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Color(0xFF8A94A6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'مشخصه‌های جدول',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044),
                  ),
                ),
                const Spacer(),
                Text(
                  '${toPersianDigits(columns.length)} مشخصه',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1876D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < columns.length; i++) ...[
              _buildColumnCard(
                context: context,
                index: i,
                column: columns[i],
                totalCount: columns.length,
                f: f,
                schema: schema,
                set: set,
                onEditColumn: onEditColumn,
              ),
              const SizedBox(height: 2),
            ],
            const SizedBox(height: 2),
            InkWell(
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
                  {'key': 'c_${newFormId()}', 'label': '', 'type': 'Text'},
                  column: true,
                  parentNative: f['native_key'] as String?,
                );
                if (result != null && context.mounted) {
                  set('columns', [...formMaps(f['columns']), result]);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB8D5FA)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, color: Color(0xFF1876D2), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'افزودن مشخصه جدید',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1876D2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildColumnCard({
  required BuildContext context,
  required int index,
  required FormMap column,
  required int totalCount,
  required FormMap f,
  required FormMap schema,
  required void Function(String key, dynamic value) set,
  required EditColumnCallback onEditColumn,
}) {
  final type = '${column['type'] ?? 'Text'}';
  final subtitle = type == 'Formula'
      ? 'محاسباتی'
      : '${_columnTypeLabel(type)} · ${column['required'] == true ? 'اجباری' : 'اختیاری'}';

  Future<void> openEdit() async {
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
      column,
      column: true,
      parentNative: f['native_key'] as String?,
    );
    if (result != null && context.mounted) {
      final cols = formMaps(f['columns']);
      cols[index] = result;
      set('columns', cols);
    }
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F2)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        InkWell(
          onTap: openEdit,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _columnBgColor(type),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              _columnIcon(type),
              color: _columnIconColor(type),
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            onTap: openEdit,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${column['label']}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF718096),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'جابه‌جایی به بالا',
              child: InkWell(
                onTap: index == 0
                    ? null
                    : () {
                        final cols = formMaps(f['columns']);
                        cols.insert(index - 1, cols.removeAt(index));
                        set('columns', cols);
                      },
                child: Padding(
                  padding: const EdgeInsets.all(0.5),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    size: 14,
                    color: index == 0
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF5B6478),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'جابه‌جایی به پایین',
              child: InkWell(
                onTap: index == totalCount - 1
                    ? null
                    : () {
                        final cols = formMaps(f['columns']);
                        cols.insert(index + 1, cols.removeAt(index));
                        set('columns', cols);
                      },
                child: Padding(
                  padding: const EdgeInsets.all(0.5),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: index == totalCount - 1
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF5B6478),
                  ),
                ),
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'تنظیمات مشخصه',
          iconSize: 14,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          visualDensity: VisualDensity.compact,
          onPressed: openEdit,
          icon: const Icon(Icons.tune, color: Color(0xFF1876D2)),
        ),
        IconButton(
          tooltip: 'حذف مشخصه',
          iconSize: 14,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final dependencies = [
              ...formMaps(column['formula_dependents']),
              ...formMaps(column['aggregate_dependents']),
              ...formMaps(column['rule_dependents']),
            ];
            if (dependencies.isNotEmpty || column['has_data'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('این مشخصه داده یا وابستگی دارد و قابل حذف نیست.'),
                ),
              );
              return;
            }
            if (!await formConfirm(context, 'مشخصه حذف شود؟') ||
                !context.mounted) {
              return;
            }
            final cols = formMaps(f['columns'])..removeAt(index);
            set('columns', cols);
          },
          icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
        ),
      ],
    ),
  );
}

Color _columnBgColor(String type) => switch (type) {
      'LongText' => const Color(0xFFE8F2FF),
      'Integer' || 'Decimal' => const Color(0xFFE5F7EF),
      'Money' => const Color(0xFFFFF0DD),
      'Date' || 'Time' || 'Formula' => const Color(0xFFF2EAFE),
      'Select' || 'Checkbox' => const Color(0xFFE6F6F7),
      'File' => const Color(0xFFE5F7EF),
      _ => const Color(0xFFE8F2FF),
    };

Color _columnIconColor(String type) => switch (type) {
      'LongText' => const Color(0xFF1876D2),
      'Integer' || 'Decimal' => const Color(0xFF0B6B3A),
      'Money' => const Color(0xFFE67E22),
      'Date' || 'Time' || 'Formula' => const Color(0xFF8654B5),
      'Select' || 'Checkbox' => const Color(0xFF00897B),
      'File' => const Color(0xFF0B6B3A),
      _ => const Color(0xFF1876D2),
    };

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
                final column = columns[i];
                final dependencies = [
                  ...formMaps(column['formula_dependents']),
                  ...formMaps(column['aggregate_dependents']),
                  ...formMaps(column['rule_dependents']),
                ];
                if (dependencies.isNotEmpty || column['has_data'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('این مشخصه داده یا وابستگی دارد و قابل حذف نیست.')),
                  );
                  return;
                }
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
