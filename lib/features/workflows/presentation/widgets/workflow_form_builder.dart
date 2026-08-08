import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/workflow_definition.dart';

class WorkflowFormBuilder extends StatelessWidget {
  const WorkflowFormBuilder({
    required this.fields,
    required this.onChanged,
    super.key,
  });

  final List<WorkflowFormFieldDefinition> fields;
  final ValueChanged<List<WorkflowFormFieldDefinition>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
              child: Text('فیلدهای فرم',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            Text('${fields.length}/۳۰',
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
          ]),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AsoudColors.primary.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AsoudColors.border),
              ),
              child: const Text(
                'هنوز فیلدی اضافه نشده است. فیلدهای موردنیاز این مرحله را تعریف کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AsoudColors.muted),
              ),
            )
          else
            for (var index = 0; index < fields.length; index++)
              _FieldCard(
                field: fields[index],
                index: index,
                count: fields.length,
                onEdit: () => _edit(context, index),
                onDelete: () {
                  final updated = [...fields]..removeAt(index);
                  onChanged(updated);
                },
                onMoveUp: index == 0 ? null : () => _move(index, index - 1),
                onMoveDown: index == fields.length - 1
                    ? null
                    : () => _move(index, index + 1),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: fields.length >= 30 ? null : () => _edit(context, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن فیلد فرم'),
          ),
        ],
      );

  void _move(int from, int to) {
    final updated = [...fields];
    final item = updated.removeAt(from);
    updated.insert(to, item);
    onChanged(updated);
  }

  Future<void> _edit(BuildContext context, int? index) async {
    final result = await showModalBottomSheet<WorkflowFormFieldDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _FieldEditor(initial: index == null ? null : fields[index]),
    );
    if (result == null) return;
    final duplicate = fields
        .asMap()
        .entries
        .any((entry) => entry.key != index && entry.value.key == result.key);
    if (duplicate && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کلید فیلد باید یکتا باشد.')));
      return;
    }
    final updated = [...fields];
    index == null ? updated.add(result) : updated[index] = result;
    onChanged(updated);
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard(
      {required this.field,
      required this.index,
      required this.count,
      required this.onEdit,
      required this.onDelete,
      this.onMoveUp,
      this.onMoveDown});
  final WorkflowFormFieldDefinition field;
  final int index, count;
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 11, 8),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AsoudColors.primary.withValues(alpha: .09),
              child: Text('${index + 1}',
                  style: const TextStyle(color: AsoudColors.primary)),
            ),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    '${_typeLabel(field.type)} • ${field.key}'
                    '${field.required ? ' • اجباری' : ''}',
                    style:
                        const TextStyle(fontSize: 9, color: AsoudColors.muted)),
              ],
            )),
            IconButton(
                onPressed: onMoveUp,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20)),
            IconButton(
                onPressed: onMoveDown,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20)),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ]),
        ),
      );
}

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({this.initial});
  final WorkflowFormFieldDefinition? initial;
  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController label;
  late final TextEditingController keyName;
  late final TextEditingController options;
  late String type;
  late bool requiredField;
  String? error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    label = TextEditingController(text: initial?.label ?? '');
    keyName = TextEditingController(text: initial?.key ?? '');
    options = TextEditingController(text: initial?.options.join('\n') ?? '');
    type = initial?.type ?? 'Short Text';
    requiredField = initial?.required ?? false;
  }

  @override
  void dispose() {
    label.dispose();
    keyName.dispose();
    options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تنظیم فیلد فرم',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
                controller: label,
                decoration: const InputDecoration(labelText: 'عنوان فیلد *')),
            const SizedBox(height: 10),
            TextField(
                controller: keyName,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'کلید فنی *', hintText: 'request_title')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع فیلد'),
              items: const [
                'Short Text',
                'Long Text',
                'Number',
                'Currency',
                'Date',
                'Choice',
                'Attachment',
                'Checkbox'
              ]
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(_typeLabel(item))))
                  .toList(),
              onChanged: (next) => setState(() => type = next ?? type),
            ),
            if (type == 'Choice') ...[
              const SizedBox(height: 10),
              TextField(
                  controller: options,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      labelText: 'گزینه‌ها *', hintText: 'هر گزینه در یک خط')),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تکمیل این فیلد اجباری باشد'),
              value: requiredField,
              onChanged: (next) => setState(() => requiredField = next),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            const SizedBox(height: 10),
            FilledButton(onPressed: _submit, child: const Text('ثبت فیلد')),
          ],
        )),
      );

  void _submit() {
    final normalizedKey = keyName.text.trim();
    final choices = options.text
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (label.text.trim().length < 2) {
      setState(() => error = 'عنوان فیلد را وارد کنید.');
      return;
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{1,39}$').hasMatch(normalizedKey)) {
      setState(
          () => error = 'کلید باید انگلیسی، یکتا و مانند request_title باشد.');
      return;
    }
    if (type == 'Choice' && choices.length < 2) {
      setState(() => error = 'حداقل دو گزینه وارد کنید.');
      return;
    }
    Navigator.pop(
        context,
        WorkflowFormFieldDefinition(
            key: normalizedKey,
            label: label.text.trim(),
            type: type,
            required: requiredField,
            options: type == 'Choice' ? choices : const []));
  }
}

String _typeLabel(String type) => switch (type) {
      'Short Text' => 'متن کوتاه',
      'Long Text' => 'متن بلند',
      'Number' => 'عدد',
      'Currency' => 'مبلغ',
      'Date' => 'تاریخ',
      'Choice' => 'انتخابی',
      'Attachment' => 'پیوست',
      'Checkbox' => 'بله/خیر',
      _ => type,
    };
