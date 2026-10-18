import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../../form_runtime.dart';
import '../editor_widgets.dart';

List<Widget> buildFormulaConfig({
  required FormMap f,
  required FormMap schema,
  required Map<String, String> fieldOptions,
  required void Function(String key, dynamic value) set,
}) {
  if (f['type'] != 'Formula') {
    return const [];
  }

  final formula = formMap(f['formula']);

  return [
    formSelect(
      'محاسبه',
      formula['op'] as String?,
      formulaOps,
      (v) => set('formula', {...formMap(f['formula']), 'op': v}),
    ),
    ExpansionTile(
      title: const Text('ورودی‌های محاسبه به ترتیب انتخاب'),
      children: [
        for (final field in fieldOptions.entries)
          CheckboxListTile(
            title: Text(field.value),
            value: (formMap(f['formula'])['inputs'] as List? ?? [])
                .contains(field.key),
            onChanged: (v) {
              final current = formMap(f['formula']),
                  inputs = [...current['inputs'] as List? ?? []];
              v == true ? inputs.add(field.key) : inputs.remove(field.key);
              set('formula', {...current, 'inputs': inputs});
            },
          ),
      ],
    ),
    formSelect(
      'جدول برای جمع یا تعداد',
      formMap(f['formula'])['table'] as String?,
      {
        for (final t in schemaFields(schema).where((t) => t['type'] == 'Table'))
          '${t['key']}': '${t['label']}',
      },
      (v) => set('formula', {
        ...formMap(f['formula']),
        'table': v,
        'columns': [],
      }),
    ),
    for (final t in schemaFields(
      schema,
    ).where((t) => t['key'] == formMap(f['formula'])['table']))
      Wrap(
        children: [
          for (final c in formMaps(t['columns']))
            FilterChip(
              label: Text('${c['label']}'),
              selected: (formMap(f['formula'])['columns'] as List? ?? [])
                  .contains(c['key']),
              onSelected: (active) {
                final current = formMap(f['formula']),
                    cols = [...current['columns'] as List? ?? []];
                active ? cols.add(c['key']) : cols.remove(c['key']);
                set('formula', {...current, 'columns': cols});
              },
            ),
        ],
      ),
    formSelect(
      'رقم اعشار',
      '${formMap(f['formula'])['precision'] ?? 2}',
      {for (var i = 0; i <= 8; i++) '$i': '$i'},
      (v) => set('formula', {
        ...formMap(f['formula']),
        'precision': int.parse(v),
      }),
    ),
    const Text(
      'محاسبه کلاینت پیش‌نمایش است؛ مبلغ در سرور با دقت ده‌دهی محاسبه می‌شود. تقسیم بر صفر خطا دارد.',
    ),
  ];
}
