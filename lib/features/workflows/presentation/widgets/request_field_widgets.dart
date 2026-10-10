import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import 'request_attachments.dart';
import 'request_custom_table.dart';
import 'request_form_controller.dart';
import 'request_link_fields.dart';

/// The `field_type` of `request_field_options` for a `System Select` [source].
String requestSourceFieldType(String? source) => switch (source) {
      'cost_center' => 'Cost Center',
      'project' => 'Project',
      'warehouse' => 'Warehouse',
      'branch' => 'Branch',
      'supplier' => 'Supplier',
      'leave_type' => 'Leave Type',
      'delivery_location' => 'Delivery Location',
      _ => source ?? '',
    };

/// Renders one form field of any type and keeps it in sync with the
/// [controller]: `Short Text`, `Long Text`, `Number`, `Currency`, `Date`
/// (Jalali picker), `Time` (24-hour), `Choice` (dropdown, chips or segmented
/// by `widget`, with `option_labels`), `Multi Choice`, `Checkbox`, `User`,
/// `Department`, `System Select` (searchable), `Auto` (read-only),
/// `Attachment`, `Table` and `Item Table`. A field hidden by `visible_when`
/// renders nothing.
class RequestFieldWidget extends StatelessWidget {
  const RequestFieldWidget(
      {required this.controller,
      required this.field,
      this.enabled = true,
      this.unified = false,
      super.key});
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;

  /// False while the form is saving.
  final bool enabled;

  /// Opt-in use of the shared [AppTextField]/[AppSelectField] look (bug #31).
  /// Off by default so the other request forms keep their current widgets.
  final bool unified;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.isVisible(field.key)
            ? Padding(
                padding: AsoudFormStyle.fieldPadding,
                child: _body(context),
              )
            : const SizedBox.shrink(),
      );

  String get _label =>
      controller.showRequiredMarks && controller.isRequired(field)
          ? '${field.label} *'
          : field.label;

  bool get _enabled => enabled && field.editable;

  ValueKey<String> get _key => ValueKey('${controller.idPrefix}:${field.key}');

  Widget _body(BuildContext context) => switch (field.type) {
        'Time' => _TimeFieldView(
            key: _key,
            controller: controller,
            field: field,
            label: _label,
            enabled: _enabled),
        'Date' => _DateFieldView(
            key: _key,
            controller: controller,
            field: field,
            label: _label,
            enabled: _enabled),
        'Choice' => _choice(context),
        'Multi Choice' => _multiChoice(),
        'Checkbox' => _checkbox(),
        'User' || 'Department' || 'System Select' => unified
            ? _UnifiedLinkField(
                key: _key,
                controller: controller,
                field: field,
                label: _label,
                enabled: _enabled)
            : _LinkFieldView(
                key: _key,
                controller: controller,
                field: field,
                label: _label,
                enabled: _enabled),
        'Auto' => _auto(),
        'Attachment' => _attachment(),
        'Table' => _table(),
        'Item Table' => _itemTable(context),
        _ => unified && _unifiedText
            ? _UnifiedTextField(
                fieldKey: _key,
                controller: controller,
                field: field,
                label: _label,
                enabled: _enabled)
            : _TextFieldView(
                fieldKey: _key,
                controller: controller,
                field: field,
                label: _label,
                enabled: _enabled),
      };

  bool get _unifiedText =>
      field.type == 'Short Text' || field.type == 'Long Text';

  Widget _heading() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(_label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      );

  Widget _error(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(message,
              style: const TextStyle(fontSize: 11, color: AsoudColors.danger)));

  Widget _help() => field.helpText.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(field.helpText,
              style: const TextStyle(fontSize: 11, color: AsoudColors.muted)));

  Widget _choice(BuildContext context) {
    final current = controller.value(field.key) as String?;
    final error = controller.errorFor(field.key);
    switch (field.widget) {
      case 'segmented':
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(),
              IgnorePointer(
                ignoring: !_enabled,
                child: AsoudSegmentedControl<String>(
                  key: _key,
                  value: current ?? '',
                  options: [
                    for (final option in field.options)
                      AsoudSegmentedOption(
                          value: option, label: field.optionLabel(option))
                  ],
                  onChanged: (value) => controller.setValue(field.key, value),
                ),
              ),
              _error(error),
              _help(),
            ]);
      case 'chips':
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(),
              Wrap(key: _key, spacing: 6, runSpacing: 6, children: [
                for (final option in field.options)
                  ChoiceChip(
                    label: Text(field.optionLabel(option)),
                    selected: current == option,
                    onSelected: !_enabled
                        ? null
                        : (selected) => controller.setValue(
                            field.key, selected ? option : null),
                  ),
              ]),
              _error(error),
              _help(),
            ]);
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(
          '${controller.idPrefix}:${field.key}:${field.options.join('|')}'),
      initialValue: field.options.contains(current) ? current : null,
      isExpanded: true,
      forceErrorText: error,
      decoration: InputDecoration(
          labelText: _label,
          helperText: field.helpText.isEmpty ? null : field.helpText),
      items: [
        for (final option in field.options)
          DropdownMenuItem(
              value: option, child: Text(field.optionLabel(option)))
      ],
      onChanged:
          _enabled ? (value) => controller.setValue(field.key, value) : null,
    );
  }

  Widget _multiChoice() {
    final current =
        ((controller.value(field.key) as List?) ?? const []).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(),
      Wrap(key: _key, spacing: 6, runSpacing: 6, children: [
        for (final option in field.options)
          FilterChip(
            label: Text(field.optionLabel(option)),
            selected: current.contains(option),
            onSelected: !_enabled
                ? null
                : (selected) {
                    final chosen = {...current};
                    selected ? chosen.add(option) : chosen.remove(option);
                    final next = field.options.where(chosen.contains).toList();
                    controller.setValue(field.key, next.isEmpty ? null : next);
                  },
          ),
      ]),
      _error(controller.errorFor(field.key)),
      _help(),
    ]);
  }

  Widget _checkbox() {
    final current = controller.value(field.key);
    return DropdownButtonFormField<bool>(
      key: ValueKey('${controller.idPrefix}:${field.key}:$current'),
      initialValue: current is bool ? current : null,
      isExpanded: true,
      forceErrorText: controller.errorFor(field.key),
      decoration: InputDecoration(labelText: _label),
      items: const [
        DropdownMenuItem(value: true, child: Text('بله')),
        DropdownMenuItem(value: false, child: Text('خیر')),
      ],
      onChanged:
          _enabled ? (value) => controller.setValue(field.key, value) : null,
    );
  }

  Widget _auto() {
    final text = controller.autoText(field.key) ??
        switch (field.auto) {
          'request_number' => 'پس از ثبت تولید می‌شود',
          'request_date' => formatJalaliIso(DateTime.now().toIso8601String()),
          _ => '—',
        };
    return InputDecorator(
      key: _key,
      decoration: InputDecoration(
        labelText: _label,
        enabled: false,
        suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
      ),
      child: Text(text, style: const TextStyle(color: AsoudColors.text)),
    );
  }

  Widget _attachment() {
    final current = controller.value(field.key) as String?;
    final choices = <String>[
      for (final draft in controller.drafts) draft.reference,
      for (final file in controller.keptExistingAttachments)
        if (file.fileUrl.isNotEmpty) file.fileUrl,
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey('${controller.idPrefix}:${field.key}:${choices.join('|')}'),
      initialValue: choices.contains(current) ? current : null,
      isExpanded: true,
      forceErrorText: controller.errorFor(field.key),
      decoration: InputDecoration(labelText: _label),
      items: [
        for (final option in choices)
          DropdownMenuItem(
              value: option,
              child: Text(controller.attachmentLabel(option) ?? option,
                  overflow: TextOverflow.ellipsis))
      ],
      onChanged:
          _enabled ? (value) => controller.setValue(field.key, value) : null,
    );
  }

  Widget _table() => RequestCustomTable(
        key: _key,
        field: field,
        enabled: _enabled,
        initialValue: [
          for (final row in (controller.value(field.key) as List?) ?? const [])
            if (row is Map) Map<String, dynamic>.from(row)
        ],
        attachments: [
          for (final draft in controller.drafts) draft.reference,
          for (final file in controller.keptExistingAttachments)
            if (file.fileUrl.isNotEmpty) file.fileUrl,
        ],
        attachmentLabel: (option) =>
            controller.attachmentLabel(option) ?? option,
        onChanged: (rows) => controller.setValue(field.key, rows),
      );

  Widget _itemTable(BuildContext context) {
    final options = field.rowOptions;
    final load = controller.loadOptions;
    return RequestItemTableField(
      key: _key,
      label: _label,
      required: controller.isRequired(field),
      enabled: _enabled,
      driven: true,
      errorText: controller.errorFor(field.key),
      rowOptions: options,
      rowFiles: options != null && options.attachment
          ? _RowFiles(controller, context)
          : null,
      items: (txt) {
        if (load == null) return Future.value(<Map<String, dynamic>>[]);
        return options == null
            ? load('Item', txt: txt)
            : load('Item', txt: txt, scope: options.itemScope);
      },
      uoms: (itemCode) => load == null
          ? Future.value(<Map<String, dynamic>>[])
          : load('UOM', itemCode: itemCode),
      initialValue: [
        for (final row in (controller.value(field.key) as List?) ?? const [])
          if (row is Map) Map<String, dynamic>.from(row)
      ],
      onChanged: (rows) => controller.setValue(field.key, rows),
    );
  }
}

/// Row files of an item table, kept in the form controller.
class _RowFiles implements RequestRowFiles {
  _RowFiles(this.controller, this.context);
  final RequestFormController controller;
  final BuildContext context;

  @override
  Future<String?> pick() async {
    final files =
        await (controller.filePicker ?? pickRequestFiles)(controller.limits);
    if (files.isEmpty) return null;
    final file = files.first;
    try {
      final ref = controller.addAttachment(
          filename: file.filename, bytes: file.bytes, general: false);
      return 'attachment:$ref';
    } on RequestAttachmentException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  @override
  String? label(String reference) => controller.attachmentLabel(reference);

  @override
  Uint8List? bytes(String reference) {
    if (!reference.startsWith('attachment:')) return null;
    final draft = controller.draft(reference.substring('attachment:'.length));
    return draft != null && draft.isImage ? draft.bytes : null;
  }

  @override
  void remove(String reference) {
    if (reference.startsWith('attachment:')) {
      controller.removeAttachment(reference.substring('attachment:'.length));
    }
  }
}

InputDecoration _decoration(WorkflowFormFieldDefinition field, String label) =>
    InputDecoration(
        labelText: label,
        helperText: field.helpText.isEmpty ? null : field.helpText);

/// Short Text, Long Text, Number and Currency.
class _TextFieldView extends StatefulWidget {
  const _TextFieldView(
      {required this.fieldKey,
      required this.controller,
      required this.field,
      required this.label,
      required this.enabled});

  /// The key of the text box itself (`<idPrefix>:<field key>`).
  final Key fieldKey;
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  @override
  State<_TextFieldView> createState() => _TextFieldViewState();
}

class _TextFieldViewState extends State<_TextFieldView> {
  late final text = TextEditingController(text: _stored);

  String get _stored {
    final value = widget.controller.value(widget.field.key);
    return value == null ? '' : '$value';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  /// An outside change of the value (e.g. a reset) reaches the text box.
  void _sync() {
    if (_stored != text.text) text.text = _stored;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final numeric = field.type == 'Number' || field.type == 'Currency';
    final long = field.type == 'Long Text' || field.widget == 'textarea';
    return TextFormField(
      key: widget.fieldKey,
      controller: text,
      enabled: widget.enabled,
      minLines: long ? 3 : 1,
      maxLines: long ? 5 : 1,
      maxLength: field.maxLength,
      buildCounter: field.maxLength == null
          ? null
          : (context,
                  {required currentLength, required isFocused, maxLength}) =>
              Text(
                  '${toPersianDigits(currentLength)}/${toPersianDigits(maxLength ?? 0)}',
                  style:
                      const TextStyle(fontSize: 10, color: AsoudColors.muted)),
      keyboardType:
          numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      forceErrorText: widget.controller.errorFor(field.key),
      decoration: _decoration(field, widget.label),
      onChanged: (value) => widget.controller.setValue(field.key, value),
    );
  }
}

/// A Jalali date; the controller keeps the ISO date.
class _DateFieldView extends StatefulWidget {
  const _DateFieldView(
      {required this.controller,
      required this.field,
      required this.label,
      required this.enabled,
      super.key});
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  @override
  State<_DateFieldView> createState() => _DateFieldViewState();
}

class _DateFieldViewState extends State<_DateFieldView> {
  late final text = TextEditingController(text: _stored);
  bool _writing = false;

  String get _stored => '${widget.controller.value(widget.field.key) ?? ''}';

  @override
  void initState() {
    super.initState();
    text.addListener(_write);
    widget.controller.addListener(_read);
  }

  void _write() {
    if (_writing) return;
    _writing = true;
    final value = text.text.trim();
    widget.controller.setValue(widget.field.key, value.isEmpty ? null : value);
    _writing = false;
  }

  void _read() {
    if (_writing || _stored == text.text) return;
    _writing = true;
    text.text = _stored;
    _writing = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AsoudFormDateField(
        controller: text,
        label: widget.label,
        required: widget.controller.isRequired(widget.field),
        enabled: widget.enabled,
        clearable: !widget.controller.isRequired(widget.field),
        errorText: widget.controller.errorFor(widget.field.key),
      );
}

/// A 24-hour time; the controller keeps `HH:MM`.
class _TimeFieldView extends StatefulWidget {
  const _TimeFieldView(
      {required this.controller,
      required this.field,
      required this.label,
      required this.enabled,
      super.key});
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  @override
  State<_TimeFieldView> createState() => _TimeFieldViewState();
}

class _TimeFieldViewState extends State<_TimeFieldView> {
  late final text = TextEditingController(text: _stored);
  bool _writing = false;

  String get _stored => '${widget.controller.value(widget.field.key) ?? ''}';

  @override
  void initState() {
    super.initState();
    text.addListener(_write);
    widget.controller.addListener(_read);
  }

  void _write() {
    if (_writing) return;
    _writing = true;
    final value = toLatinDigits(text.text.trim());
    widget.controller.setValue(widget.field.key, value.isEmpty ? null : value);
    _writing = false;
  }

  void _read() {
    if (_writing || _stored == text.text) return;
    _writing = true;
    text.text = _stored;
    _writing = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AsoudFormTimeField(
        controller: text,
        label: widget.label,
        required: widget.controller.isRequired(widget.field),
        enabled: widget.enabled,
        clearable: !widget.controller.isRequired(widget.field),
        errorText: widget.controller.errorFor(widget.field.key),
      );
}

/// A searchable single choice: `User`, `Department` or a `System Select`.
class _LinkFieldView extends StatelessWidget {
  const _LinkFieldView(
      {required this.controller,
      required this.field,
      required this.label,
      required this.enabled,
      super.key});
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  String get _fieldType => field.type == 'System Select'
      ? requestSourceFieldType(field.source)
      : field.type;

  Future<void> _pick(BuildContext context) async {
    final load = controller.loadOptions;
    final row = await showRequestOptionPicker(context,
        title: field.label,
        loader: (txt) async =>
            load == null ? const [] : load(_fieldType, txt: txt));
    if (row == null) return;
    controller.setValue(field.key, '${row['value']}',
        label: persianLeaveTypeLabel('${row['label'] ?? row['value']}'));
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value(field.key) as String?;
    final rawShown = controller.labelFor(field.key) ?? value;
    final shown = persianLeaveTypeLabel(rawShown);
    final error = controller.errorFor(field.key);
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          helperText: field.helpText.isEmpty ? null : field.helpText,
          enabled: enabled,
          suffixIcon: !field.editable
              ? const Icon(Icons.lock_outline_rounded, size: 18)
              : value != null && !controller.isRequired(field) && enabled
                  ? IconButton(
                      tooltip: 'پاک کردن انتخاب',
                      onPressed: () => controller.setValue(field.key, null),
                      icon: const Icon(Icons.close_rounded, size: 18))
                  : const Icon(Icons.search_rounded),
        ),
        child: Text(shown,
            style: TextStyle(
                color: value == null ? AsoudColors.muted : AsoudColors.text)),
      ),
    );
  }
}

/// The unified look (bug #31) of a `User`, `Department` or `System Select`:
/// an [AppSelectField] that opens the same searchable option picker, but with
/// the shared label/border/⌄ language.
class _UnifiedLinkField extends StatefulWidget {
  const _UnifiedLinkField(
      {required this.controller,
      required this.field,
      required this.label,
      required this.enabled,
      super.key});
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  @override
  State<_UnifiedLinkField> createState() => _UnifiedLinkFieldState();
}

class _UnifiedLinkFieldState extends State<_UnifiedLinkField> {
  String? _pickedLabel;

  String get _fieldType => widget.field.type == 'System Select'
      ? requestSourceFieldType(widget.field.source)
      : widget.field.type;

  Future<String?> _pick() async {
    final load = widget.controller.loadOptions;
    final row = await showRequestOptionPicker(context,
        title: widget.field.label,
        loader: (txt) async =>
            load == null ? const [] : load(_fieldType, txt: txt));
    if (row == null) return null;
    _pickedLabel =
        persianLeaveTypeLabel('${row['label'] ?? row['value']}');
    return '${row['value']}';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value(widget.field.key) as String?;
    final rawShown =
        widget.controller.labelFor(widget.field.key) ?? _pickedLabel ?? value;
    return AppSelectField(
      label: widget.label,
      value: value ?? '',
      displayValue: rawShown == null ? null : persianLeaveTypeLabel(rawShown),
      hint: 'انتخاب کنید',
      enabled: widget.enabled,
      errorText: widget.controller.errorFor(widget.field.key),
      helperText: widget.field.helpText.isEmpty ? null : widget.field.helpText,
      onPick: widget.enabled ? _pick : null,
      onChanged: (picked) => widget.controller.setValue(
          widget.field.key, picked.isEmpty ? null : picked,
          label: picked.isEmpty ? null : _pickedLabel),
    );
  }
}

/// The unified look (bug #31) of a `Short Text` / `Long Text`: the same
/// controller sync as [_TextFieldView] but rendered with [AppTextField].
class _UnifiedTextField extends StatefulWidget {
  const _UnifiedTextField(
      {required this.fieldKey,
      required this.controller,
      required this.field,
      required this.label,
      required this.enabled});
  final Key fieldKey;
  final RequestFormController controller;
  final WorkflowFormFieldDefinition field;
  final String label;
  final bool enabled;

  @override
  State<_UnifiedTextField> createState() => _UnifiedTextFieldState();
}

class _UnifiedTextFieldState extends State<_UnifiedTextField> {
  late final text = TextEditingController(text: _stored);

  String get _stored {
    final value = widget.controller.value(widget.field.key);
    return value == null ? '' : '$value';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  void _sync() {
    if (_stored != text.text) text.text = _stored;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final long = field.type == 'Long Text' || field.widget == 'textarea';
    return AppTextField(
      key: widget.fieldKey,
      controller: text,
      label: widget.label,
      enabled: widget.enabled,
      minLines: long ? 3 : 1,
      maxLines: long ? 5 : 1,
      maxLength: field.maxLength,
      errorText: widget.controller.errorFor(field.key),
      helperText: field.helpText.isEmpty ? null : field.helpText,
      counterBuilder: field.maxLength == null
          ? null
          : (context,
                  {required currentLength, required isFocused, maxLength}) =>
              Text(
                  '${toPersianDigits(currentLength)}/${toPersianDigits(maxLength ?? 0)}',
                  style:
                      const TextStyle(fontSize: 10, color: AsoudColors.muted)),
      onChanged: (value) => widget.controller.setValue(field.key, value),
    );
  }
}

/// A section card like the form pages use («اطلاعات اصلی», «اقلام درخواست»):
/// [title] with an optional [icon], then [children].
class RequestFormCard extends StatelessWidget {
  const RequestFormCard(
      {required this.title, required this.children, this.icon, super.key});
  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: AsoudFormStyle.sectionMargin,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title.isNotEmpty) ...[
              Row(children: [
                if (icon != null) ...[
                  AsoudIconBox(
                      icon: icon!, color: AsoudColors.primary, size: 30),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: Text(title, style: AsoudFormStyle.sectionTitle)),
              ]),
              const SizedBox(height: 12),
            ],
            ...children,
          ]),
        ),
      );
}
