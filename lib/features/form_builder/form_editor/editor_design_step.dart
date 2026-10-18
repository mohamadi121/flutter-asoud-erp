import 'package:flutter/material.dart';

import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_widgets.dart';

class EditorDesignStep extends StatelessWidget {
  const EditorDesignStep({
    required this.schema,
    required this.change,
    required this.onEditField,
    super.key,
  });

  final FormMap schema;
  final void Function(VoidCallback fn) change;
  final Future<void> Function(FormMap section, [int? index]) onEditField;

  @override
  Widget build(BuildContext context) {
    final sections = formMaps(schema['sections']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final title = await formText(context, 'عنوان بخش جدید', '');
            if (title == null || title.isEmpty || !context.mounted) {
              return;
            }
            change(
              () => schema['sections'] = [
                ...sections,
                {'id': newFormId(), 'title': title, 'fields': <FormMap>[]},
              ],
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('افزودن بخش'),
        ),
        for (var si = 0; si < sections.length; si++)
          buildSectionCard(context, sections, si),
      ],
    );
  }

  Widget buildSectionCard(
    BuildContext context,
    List<FormMap> sections,
    int si,
  ) =>
      Card(
        child: ExpansionTile(
          key: ValueKey(sections[si]['id']),
          initiallyExpanded: true,
          title: Text('${sections[si]['title']}'),
          childrenPadding: const EdgeInsets.all(10),
          children: [
            Wrap(
              children: [
                TextButton(
                  onPressed: () async {
                    final title = await formText(
                      context,
                      'نام بخش',
                      '${sections[si]['title']}',
                    );
                    if (title != null && title.isNotEmpty && context.mounted) {
                      change(() {
                        sections[si]['title'] = title;
                        schema['sections'] = sections;
                      });
                    }
                  },
                  child: const Text('تغییر نام'),
                ),
                IconButton(
                  tooltip: 'بخش بالاتر',
                  onPressed: si == 0
                      ? null
                      : () => change(() {
                            final s = sections.removeAt(si);
                            sections.insert(si - 1, s);
                            schema['sections'] = sections;
                          }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'بخش پایین‌تر',
                  onPressed: si == sections.length - 1
                      ? null
                      : () => change(() {
                            final s = sections.removeAt(si);
                            sections.insert(si + 1, s);
                            schema['sections'] = sections;
                          }),
                  icon: const Icon(Icons.arrow_downward),
                ),
                TextButton(
                  onPressed: sections.length < 2
                      ? null
                      : () async {
                          if (!await formConfirm(
                                context,
                                'بخش حذف و فیلدهای آن به بخش دیگری منتقل شوند؟',
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          change(() {
                            final removed = sections.removeAt(si);
                            final target = sections.first;
                            target['fields'] = [
                              ...formMaps(target['fields']),
                              ...formMaps(removed['fields']),
                            ];
                            schema['sections'] = sections;
                          });
                        },
                  child: const Text('حذف و انتقال فیلدها'),
                ),
              ],
            ),
            for (var fi = 0;
                fi < formMaps(sections[si]['fields']).length;
                fi++)
              buildFieldRow(context, sections, si, fi),
            OutlinedButton.icon(
              onPressed: () async {
                schema['sections'] = sections;
                await onEditField(sections[si]);
              },
              icon: const Icon(Icons.add),
              label: const Text('افزودن فیلد'),
            ),
          ],
        ),
      );

  Widget buildFieldRow(
    BuildContext context,
    List<FormMap> sections,
    int si,
    int fi,
  ) {
    final fields = formMaps(sections[si]['fields']), f = fields[fi];
    return ListTile(
      title: Text('${f['label']}'),
      subtitle: Text(formTypes[f['type']] ?? ''),
      onTap: () async {
        schema['sections'] = sections;
        await onEditField(sections[si], fi);
      },
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'delete' &&
              !await formConfirm(context, 'فیلد و قوانین وابسته حذف شوند؟')) {
            return;
          }
          if (!context.mounted) {
            return;
          }
          change(() {
            if (action == 'delete') {
              fields.removeAt(fi);
              schema['rules'] = formMaps(schema['rules'])
                  .where(
                    (r) =>
                        r['target'] != f['key'] &&
                        !formMaps(r['conditions'])
                            .any((c) => c['field'] == f['key']),
                  )
                  .toList();
            }
            if (action == 'copy') {
              fields.insert(fi + 1, {
                ...copyForm(f),
                'key': 'f_${newFormId()}',
                'label': '${f['label']} (کپی)',
                'native_key': null,
              });
            }
            if (action == 'up' && fi > 0) {
              fields.insert(fi - 1, fields.removeAt(fi));
            }
            if (action == 'down' && fi < fields.length - 1) {
              fields.insert(fi + 1, fields.removeAt(fi));
            }
            if (action.startsWith('move:')) {
              final target = sections.firstWhere(
                (s) => s['id'] == action.substring(5),
              );
              target['fields'] = [
                ...formMaps(target['fields']),
                fields.removeAt(fi),
              ];
            }
            sections[si]['fields'] = fields;
            schema['sections'] = sections;
          });
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'copy', child: Text('تکثیر')),
          if (fi > 0) const PopupMenuItem(value: 'up', child: Text('بالا')),
          if (fi < fields.length - 1)
            const PopupMenuItem(value: 'down', child: Text('پایین')),
          for (final section in sections.where(
            (s) => s['id'] != sections[si]['id'],
          ))
            PopupMenuItem(
              value: 'move:${section['id']}',
              child: Text('انتقال به ${section['title']}'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    );
  }
}
