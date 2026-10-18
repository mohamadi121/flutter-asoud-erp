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
    for (var i = 0; i < columns.length; i++)
      ListTile(
        title: Text('${columns[i]['label']}'),
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
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete' &&
                !await formConfirm(context, 'ستون حذف شود؟')) {
              return;
            }
            final cols = formMaps(f['columns']);
            if (v == 'delete') {
              cols.removeAt(i);
            } else if (v == 'up' && i > 0) {
              cols.insert(i - 1, cols.removeAt(i));
            } else if (v == 'down' && i < cols.length - 1) {
              cols.insert(i + 1, cols.removeAt(i));
            }
            if (context.mounted) {
              set('columns', cols);
            }
          },
          itemBuilder: (_) => [
            if (i > 0)
              const PopupMenuItem(value: 'up', child: Text('بالا')),
            if (i < columns.length - 1)
              const PopupMenuItem(value: 'down', child: Text('پایین')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    OutlinedButton(
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
      child: const Text('افزودن ستون'),
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
