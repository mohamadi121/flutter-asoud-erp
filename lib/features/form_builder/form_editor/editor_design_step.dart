import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'design/section_palette.dart';
import 'editor_widgets.dart';

class EditorDesignStep extends StatefulWidget {
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
  State<EditorDesignStep> createState() => _EditorDesignStepState();
}

class _EditorDesignStepState extends State<EditorDesignStep> {
  final Set<String> _expandedSectionIds = {};
  bool _initializedExpansion = false;

  void _ensureSectionColors(List<FormMap> sections) {
    var changed = false;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i]['color'] == null ||
          '${sections[i]['color']}'.trim().isEmpty) {
        sections[i]['color'] = sectionColorPalette[i % sectionColorPalette.length].hex;
        changed = true;
      }
    }
    if (changed) {
      widget.schema['sections'] = sections;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = formMaps(widget.schema['sections']);
    _ensureSectionColors(sections);

    if (!_initializedExpansion && sections.isNotEmpty) {
      _expandedSectionIds.add('${sections.first['id']}');
      _initializedExpansion = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header Row: "بخش‌های فرم" + "+ افزودن بخش"
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'بخش‌های فرم',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => _addSection(context, sections),
                icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                label: const Text(
                  'افزودن بخش',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (sections.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.folder_open_outlined,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هنوز بخشی برای فرم ایجاد نشده است.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _addSection(context, sections),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('افزودن اولین بخش'),
                ),
              ],
            ),
          )
        else
          for (var si = 0; si < sections.length; si++) ...[
            _buildSectionCard(context, sections, si),
            if (si < sections.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _addSection(BuildContext context, List<FormMap> sections) async {
    final title = await formText(context, 'عنوان بخش جدید', '');
    if (title == null || title.trim().isEmpty || !context.mounted) {
      return;
    }
    final nextColor = pickNextSectionColor(sections);
    final newId = 'sec_${newFormId()}';
    widget.change(() {
      final updated = [
        ...sections,
        {
          'id': newId,
          'title': title.trim(),
          'color': nextColor,
          'fields': <FormMap>[],
        },
      ];
      widget.schema['sections'] = updated;
      _expandedSectionIds.add(newId);
    });
  }

  Widget _buildSectionCard(
    BuildContext context,
    List<FormMap> sections,
    int si,
  ) {
    final section = sections[si];
    final sectionId = '${section['id']}';
    final isExpanded = _expandedSectionIds.contains(sectionId);
    final colorInfo = resolveSectionColor(section['color'] as String?, si);
    final fields = formMaps(section['fields']);

    return Container(
      key: ValueKey('sec_$sectionId'),
      decoration: BoxDecoration(
        color: colorInfo.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorInfo.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSectionIds.remove(sectionId);
                } else {
                  _expandedSectionIds.add(sectionId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Folder icon in white square on the right (RTL start)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorInfo.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: colorInfo.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title & count in middle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${section['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${toPersianDigits(fields.length)} فیلد',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Expansion arrow on the left (RTL end)
                  IconButton(
                    iconSize: 20,
                    tooltip: isExpanded ? 'بستن بخش' : 'باز کردن بخش',
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedSectionIds.remove(sectionId);
                        } else {
                          _expandedSectionIds.add(sectionId);
                        }
                      });
                    },
                  ),
                  // 3-dots actions menu
                  PopupMenuButton<String>(
                    tooltip: 'عملیات بخش',
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onSelected: (action) => _handleSectionAction(
                      context,
                      sections,
                      si,
                      action,
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('تغییر نام'),
                          ],
                        ),
                      ),
                      if (si > 0)
                        const PopupMenuItem(
                          value: 'up',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward, size: 18),
                              SizedBox(width: 8),
                              Text('انتقال به بالا'),
                            ],
                          ),
                        ),
                      if (si < sections.length - 1)
                        const PopupMenuItem(
                          value: 'down',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward, size: 18),
                              SizedBox(width: 8),
                              Text('انتقال به پایین'),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: sections.length > 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: sections.length > 1
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'حذف بخش',
                                  style: TextStyle(
                                    color: sections.length > 1
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            if (sections.length <= 1)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'فرم باید حداقل یک بخش داشته باشد',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content: Fields list + Add field button
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      const spacing = 8.0;
                      final halfWidth = (totalWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 0,
                        children: [
                          for (var fi = 0; fi < fields.length; fi++)
                            SizedBox(
                              width: (fields[fi]['span'] as num?)?.toInt() == 1
                                  ? halfWidth
                                  : totalWidth,
                              child: _buildFieldCard(
                                context,
                                sections,
                                si,
                                fi,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      widget.schema['sections'] = sections;
                      await widget.onEditField(section);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'افزودن فیلد',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 38),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    List<FormMap> sections,
    int si,
    int fi,
  ) {
    final fields = formMaps(sections[si]['fields']);
    final f = fields[fi];
    final visual = getFieldVisual(f['type'] as String?);
    final isRequired = f['required'] == true;
    final typeName = formTypes[f['type']] ?? '${f['type'] ?? ''}';

    return Container(
      key: ValueKey('field_${f['key']}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          widget.schema['sections'] = sections;
          await widget.onEditField(sections[si], fi);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Field type icon container on the right (RTL start)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: visual.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  visual.icon,
                  size: 18,
                  color: visual.color,
                ),
              ),
              const SizedBox(width: 8),
              // Field title & type in middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${f['label'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isRequired)
                          const Text(
                            ' *',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tune / Settings button and more actions on the left (RTL end)
              PopupMenuButton<String>(
                tooltip: 'عملیات فیلد',
                icon: const Icon(
                  Icons.tune,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                onSelected: (action) => _handleFieldAction(
                  context,
                  sections,
                  si,
                  fi,
                  action,
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('تنظیمات فیلد'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('تکثیر فیلد'),
                      ],
                    ),
                  ),
                  if (fi > 0)
                    const PopupMenuItem(
                      value: 'up',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, size: 18),
                          SizedBox(width: 8),
                          Text('انتقال به بالا'),
                        ],
                      ),
                    ),
                  if (fi < fields.length - 1)
                    const PopupMenuItem(
                      value: 'down',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, size: 18),
                          SizedBox(width: 8),
                          Text('انتقال به پایین'),
                        ],
                      ),
                    ),
                  for (final sec in sections.where(
                    (s) => s['id'] != sections[si]['id'],
                  ))
                    PopupMenuItem(
                      value: 'move:${sec['id']}',
                      child: Row(
                        children: [
                          const Icon(Icons.drive_file_move_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'انتقال به ${sec['title']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('حذف فیلد',
                            style: TextStyle(color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSectionAction(
    BuildContext context,
    List<FormMap> sections,
    int si,
    String action,
  ) async {
    if (action == 'rename') {
      final title = await formText(
        context,
        'نام بخش',
        '${sections[si]['title']}',
      );
      if (title != null && title.trim().isNotEmpty && context.mounted) {
        widget.change(() {
          sections[si]['title'] = title.trim();
          widget.schema['sections'] = sections;
        });
      }
    } else if (action == 'up' && si > 0) {
      widget.change(() {
        final s = sections.removeAt(si);
        sections.insert(si - 1, s);
        widget.schema['sections'] = sections;
      });
    } else if (action == 'down' && si < sections.length - 1) {
      widget.change(() {
        final s = sections.removeAt(si);
        sections.insert(si + 1, s);
        widget.schema['sections'] = sections;
      });
    } else if (action == 'delete') {
      if (sections.length <= 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فرم باید حداقل یک بخش داشته باشد'),
            ),
          );
        }
        return;
      }
      final fields = formMaps(sections[si]['fields']);
      final confirm = await formConfirm(
        context,
        'بخش «${sections[si]['title']}» شامل ${toPersianDigits(fields.length)} فیلد حذف شود؟',
      );
      if (confirm && context.mounted) {
        widget.change(() {
          sections.removeAt(si);
          widget.schema['sections'] = sections;
        });
      }
    }
  }

  Future<void> _handleFieldAction(
    BuildContext context,
    List<FormMap> sections,
    int si,
    int fi,
    String action,
  ) async {
    final fields = formMaps(sections[si]['fields']);
    final f = fields[fi];

    if (action == 'edit') {
      widget.schema['sections'] = sections;
      await widget.onEditField(sections[si], fi);
    } else if (action == 'delete') {
      final confirm =
          await formConfirm(context, 'فیلد و قوانین وابسته حذف شوند؟');
      if (!confirm || !context.mounted) {
        return;
      }
      widget.change(() {
        fields.removeAt(fi);
        widget.schema['rules'] = formMaps(widget.schema['rules'])
            .where(
              (r) =>
                  r['target'] != f['key'] &&
                  !formMaps(r['conditions']).any((c) => c['field'] == f['key']),
            )
            .toList();
        sections[si]['fields'] = fields;
        widget.schema['sections'] = sections;
      });
    } else if (action == 'copy') {
      widget.change(() {
        fields.insert(fi + 1, {
          ...copyForm(f),
          'key': 'f_${newFormId()}',
          'label': '${f['label']} (کپی)',
          'native_key': null,
        });
        sections[si]['fields'] = fields;
        widget.schema['sections'] = sections;
      });
    } else if (action == 'up' && fi > 0) {
      widget.change(() {
        fields.insert(fi - 1, fields.removeAt(fi));
        sections[si]['fields'] = fields;
        widget.schema['sections'] = sections;
      });
    } else if (action == 'down' && fi < fields.length - 1) {
      widget.change(() {
        fields.insert(fi + 1, fields.removeAt(fi));
        sections[si]['fields'] = fields;
        widget.schema['sections'] = sections;
      });
    } else if (action.startsWith('move:')) {
      final targetId = action.substring(5);
      widget.change(() {
        final target = sections.firstWhere((s) => s['id'] == targetId);
        target['fields'] = [
          ...formMaps(target['fields']),
          fields.removeAt(fi),
        ];
        sections[si]['fields'] = fields;
        widget.schema['sections'] = sections;
      });
    }
  }
}
