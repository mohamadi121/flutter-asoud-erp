import 'package:flutter/material.dart';

import '../form_repository.dart';
import 'form_fields_view.dart';

Widget? buildTableField({
  required FormMap f,
  required dynamic value,
  required String label,
  required bool editable,
  required bool snapshot,
  required FormRepository repository,
  required String? formName,
  required ValueChanged<dynamic> onChanged,
}) {
  if (f['type'] != 'Table') {
    return null;
  }

  final key = '${f['key']}';
  final rows = formMaps(value);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label),
      for (var i = 0; i < rows.length; i++)
        Card(
          child: Column(
            children: [
              FormFieldsView(
                key: ValueKey('$key:$i'),
                schema: {
                  'sections': [
                    {
                      'id': '$key:$i',
                      'title': 'ردیف ${i + 1}',
                      'fields': f['columns'],
                    },
                  ],
                  'rules': [],
                },
                values: rows[i],
                repository: repository,
                formName: formName,
                enabled: editable,
                snapshot: snapshot,
                onChanged: (row) {
                  rows[i] = row;
                  onChanged(rows);
                },
              ),
              if (editable)
                TextButton.icon(
                  onPressed: () {
                    rows.removeAt(i);
                    onChanged(rows);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف ردیف'),
                ),
            ],
          ),
        ),
      if (editable)
        OutlinedButton.icon(
          onPressed: rows.length >= ((f['max_rows'] as num?)?.toInt() ?? 100)
              ? null
              : () => onChanged([...rows, <String, dynamic>{}]),
          icon: const Icon(Icons.add),
          label: const Text('افزودن ردیف'),
        ),
    ],
  );
}
