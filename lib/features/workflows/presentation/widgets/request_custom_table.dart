import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../domain/entities/workflow_definition.dart';

/// A configurable request table. Preview rows are isolated from request values.
class RequestCustomTable extends StatefulWidget {
  const RequestCustomTable(
      {required this.field,
      required this.onChanged,
      this.initialValue = const [],
      this.attachments = const [],
      this.uploadAttachment,
      this.enabled = true,
      this.preview = false,
      super.key});
  final WorkflowFormFieldDefinition field;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final List<Map<String, dynamic>> initialValue;
  final List<String> attachments;
  final Future<String?> Function()? uploadAttachment;
  final bool enabled, preview;

  @override
  State<RequestCustomTable> createState() => _RequestCustomTableState();
}

class _RequestCustomTableState extends State<RequestCustomTable> {
  late final rows = [
    for (final row in widget.initialValue) Map<String, dynamic>.of(row),
    if (widget.preview && widget.initialValue.isEmpty) <String, dynamic>{},
  ];
  late final ids = List.generate(rows.length, (index) => index);
  late int nextId = rows.length;
  final uploaded = <String>{};

  String? _validate(List<Map<String, dynamic>>? _) {
    if (widget.preview) return null;
    if (widget.field.required && rows.isEmpty) {
      return 'حداقل یک ردیف اضافه کنید.';
    }
    for (var i = 0; i < rows.length; i++) {
      for (final column in widget.field.columns) {
        final text = rows[i][column.key]?.toString().trim() ?? '';
        final prefix = 'ردیف ${i + 1}، ${column.label}: ';
        if (column.required && text.isEmpty) return '${prefix}الزامی است.';
        if (text.isEmpty) continue;
        if (column.type == 'Number' || column.type == 'Currency') {
          final number = num.tryParse(text);
          if (number == null || !number.isFinite) {
            return '${prefix}عدد معتبر وارد کنید.';
          }
        }
        if (column.type == 'Date' && asoudDateValidator(text) != null) {
          return '${prefix}تاریخ معتبر با قالب YYYY-MM-DD وارد کنید.';
        }
        if (column.type == 'Choice' && !column.options.contains(text)) {
          return '${prefix}یکی از گزینه‌های موجود را انتخاب کنید.';
        }
        if (column.type == 'Attachment' &&
            !widget.attachments.contains(text) &&
            !uploaded.contains(text)) {
          return '${prefix}یک فایل از پیوست‌های درخواست انتخاب کنید.';
        }
        if (text.length > 10000) return '${prefix}متن بیش از حد طولانی است.';
      }
    }
    return null;
  }

  void _publish(FormFieldState<List<Map<String, dynamic>>> state) {
    final value = [for (final row in rows) Map<String, dynamic>.of(row)];
    state.didChange(value);
    if (!widget.preview) widget.onChanged(value);
  }

  Widget _cell(WorkflowFormFieldDefinition column, int index,
      FormFieldState<List<Map<String, dynamic>>> state) {
    final value = rows[index][column.key]?.toString() ?? '';
    void changed(String? value) {
      rows[index][column.key] = value;
      _publish(state);
    }

    final decoration = InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        hintText: column.type == 'Date' ? 'YYYY-MM-DD' : null);
    if (column.type == 'Attachment' && widget.uploadAttachment != null) {
      return OutlinedButton.icon(
          onPressed: !widget.enabled || widget.preview
              ? null
              : () async {
                  final row = rows[index];
                  final url = await widget.uploadAttachment!();
                  if (!mounted || url == null || !rows.contains(row)) return;
                  setState(() {
                    uploaded.add(url);
                    row[column.key] = url;
                    _publish(state);
                  });
                },
          icon: const Icon(Icons.attach_file_rounded, size: 16),
          label: Text(value.isEmpty ? 'انتخاب فایل' : value.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10)));
    }
    if (column.type == 'Choice' || column.type == 'Attachment') {
      final options =
          column.type == 'Choice' ? column.options : widget.attachments;
      return DropdownButtonFormField<String>(
          key: ValueKey('${ids[index]}:${column.key}:${options.join('|')}'),
          initialValue: options.contains(value) ? value : null,
          isExpanded: true,
          decoration: decoration,
          style: const TextStyle(fontSize: 11, color: AsoudColors.text),
          items: [
            for (final option in options.toSet())
              DropdownMenuItem(
                  value: option,
                  child: Text(option.replaceFirst('attachment:', ''),
                      overflow: TextOverflow.ellipsis))
          ],
          onChanged: widget.enabled && !widget.preview ? changed : null);
    }
    return TextFormField(
        key: ValueKey('${ids[index]}:${column.key}'),
        initialValue: value,
        enabled: widget.enabled && !widget.preview,
        style: const TextStyle(fontSize: 11),
        decoration: decoration,
        keyboardType: column.type == 'Number' || column.type == 'Currency'
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        onChanged: changed);
  }

  @override
  Widget build(BuildContext context) => FormField<List<Map<String, dynamic>>>(
        initialValue: rows,
        validator: _validate,
        builder: (state) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.field.label.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    '${widget.field.label}${widget.field.required ? ' *' : ''}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800))),
          if (widget.field.columns.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('ستون‌های جدول را اضافه کنید.',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted)))
          else
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        for (final column in widget.field.columns)
                          Container(
                              width: 126,
                              padding: const EdgeInsets.all(10),
                              color: AsoudColors.primary.withValues(alpha: .06),
                              child: Text(
                                  '${column.label.isEmpty ? 'نام ستون' : column.label}${column.required ? ' *' : ''}',
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))),
                        Container(
                            width: 48,
                            padding: const EdgeInsets.all(10),
                            color: AsoudColors.primary.withValues(alpha: .06),
                            child: const Text('حذف',
                                style: TextStyle(fontSize: 10))),
                      ]),
                      for (var index = 0; index < rows.length; index++)
                        Row(key: ValueKey(ids[index]), children: [
                          for (final column in widget.field.columns)
                            SizedBox(
                                width: 126,
                                child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: _cell(column, index, state))),
                          SizedBox(
                              width: 48,
                              child: IconButton(
                                  tooltip: 'حذف ردیف',
                                  onPressed: !widget.enabled || widget.preview
                                      ? null
                                      : () => setState(() {
                                            rows.removeAt(index);
                                            ids.removeAt(index);
                                            _publish(state);
                                          }),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: AsoudColors.danger))),
                        ]),
                    ])),
          if (state.errorText != null)
            Text(state.errorText!,
                style:
                    const TextStyle(fontSize: 11, color: AsoudColors.danger)),
          if (!widget.preview)
            TextButton.icon(
                onPressed: !widget.enabled || rows.length >= 100
                    ? null
                    : () => setState(() {
                          rows.add({});
                          ids.add(nextId++);
                          _publish(state);
                        }),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('افزودن ردیف')),
        ]),
      );
}
