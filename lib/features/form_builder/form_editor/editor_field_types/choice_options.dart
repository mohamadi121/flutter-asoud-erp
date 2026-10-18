import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../form_repository.dart';
import '../../form_runtime/schema_migration.dart';

Widget? buildChoiceOptionsConfig(FormMap f, [VoidCallback? onChanged]) {
  if (!['Select', 'MultiSelect', 'Checkbox'].contains(f['type'])) {
    return null;
  }
  return ChoiceOptionsListEditor(field: f, onChanged: onChanged);
}

class ChoiceOptionsListEditor extends StatefulWidget {
  const ChoiceOptionsListEditor({
    required this.field,
    this.onChanged,
    super.key,
  });

  final FormMap field;
  final VoidCallback? onChanged;

  @override
  State<ChoiceOptionsListEditor> createState() => _ChoiceOptionsListEditorState();
}

class _ChoiceOptionsListEditorState extends State<ChoiceOptionsListEditor> {
  late List<FormMap> _options;

  @override
  void initState() {
    super.initState();
    _options = List<FormMap>.from(
      choiceOptions(widget.field).map((o) => Map<String, dynamic>.from(o)),
    );
    widget.field['options'] = _options;
  }

  void _sync() {
    widget.field['options'] = _options;
    widget.onChanged?.call();
    setState(() {});
  }

  void _addOption() {
    _options.add({
      'id': newChoiceOptionId(),
      'label': 'گزینه جدید',
    });
    _sync();
  }

  void _removeOption(int index) {
    _options.removeAt(index);
    _sync();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _options.length) return;
    final item = _options.removeAt(index);
    _options.insert(target, item);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'گزینه‌ها (هر خط یک گزینه)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF122044),
              ),
            ),
            Text(
              'تعداد: ${toPersianDigits(_options.length)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B6478)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _options.length,
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            final item = _options.removeAt(oldIndex);
            _options.insert(newIndex, item);
            _sync();
          },
          itemBuilder: (context, index) {
            final opt = _options[index];
            final optId = '${opt['id']}';
            return Container(
              key: ValueKey(optId),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: 'تغییر ترتیب',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: Color(0xFF5B6478),
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'جابه‌جایی به بالا',
                    child: InkWell(
                      onTap: index == 0 ? null : () => _move(index, -1),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          size: 18,
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
                      onTap: index == _options.length - 1
                          ? null
                          : () => _move(index, 1),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: index == _options.length - 1
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF5B6478),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('title_$optId'),
                      initialValue: '${opt['label'] ?? ''}',
                      decoration: const InputDecoration(
                        hintText: 'عنوان گزینه...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onChanged: (val) {
                        opt['label'] = val;
                        widget.field['options'] = _options;
                        widget.onChanged?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'حذف گزینه',
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFD64545),
                    ),
                    onPressed: () => _removeOption(index),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _addOption,
          icon: const Icon(Icons.add, size: 18, color: Color(0xFF1876D2)),
          label: const Text(
            'افزودن گزینه',
            style: TextStyle(color: Color(0xFF1876D2), fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFBCD8FF)),
            backgroundColor: const Color(0xFFF8FAFD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }
}
