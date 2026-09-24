import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../domain/request_type_catalog.dart';

/// Add or edit one custom field. Pops the saved field.
class RequestFieldEditorPage extends StatefulWidget {
  const RequestFieldEditorPage(
      {required this.type, this.initial, this.takenKeys = const {}, super.key});
  final String type;
  final WorkflowFormFieldDefinition? initial;
  final Set<String> takenKeys;

  @override
  State<RequestFieldEditorPage> createState() => _RequestFieldEditorPageState();
}

class _RequestFieldEditorPageState extends State<RequestFieldEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final initial = widget.initial;
  late final label = TextEditingController(text: initial?.label ?? '');
  late final key = TextEditingController(text: initial?.key ?? '');
  late final help = TextEditingController(text: initial?.helpText ?? '');
  late final defaultValue =
      TextEditingController(text: initial?.defaultValue ?? '');
  late final options = [
    for (final option in initial?.options ?? const <String>[])
      TextEditingController(text: option),
  ];
  late bool required = initial?.required ?? false;
  late bool showInList = initial?.showInList ?? false;
  String? optionsError;

  bool get isChoice => widget.type == 'Choice' || widget.type == 'Multi Choice';
  bool get hasDefault => !requestFieldTypesWithoutDefault.contains(widget.type);

  @override
  void initState() {
    super.initState();
    if (isChoice && options.isEmpty) {
      options.addAll([TextEditingController(), TextEditingController()]);
    }
  }

  @override
  void dispose() {
    for (final controller in [label, key, help, defaultValue, ...options]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _freeKey() {
    var index = 1;
    while (widget.takenKeys.contains('field_$index')) {
      index++;
    }
    return 'field_$index';
  }

  String? _validateKey(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!requestFieldKeyPattern.hasMatch(text)) {
      return 'فقط حروف کوچک انگلیسی، عدد و _ (مثال: purchase_type)';
    }
    if (widget.takenKeys.contains(text)) return 'این نام فنی تکراری است.';
    return null;
  }

  String? _validateDefault(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if ((widget.type == 'Number' || widget.type == 'Currency') &&
        num.tryParse(text) == null) {
      return 'مقدار پیش‌فرض باید عدد باشد.';
    }
    if (widget.type == 'Date') return asoudDateValidator(text);
    if (isChoice && !options.any((option) => option.text.trim() == text)) {
      return 'مقدار پیش‌فرض باید یکی از گزینه‌ها باشد.';
    }
    return null;
  }

  void _save() {
    final values = [
      for (final option in options)
        if (option.text.trim().isNotEmpty) option.text.trim(),
    ];
    setState(() => optionsError = isChoice &&
            (values.length < 2 || values.toSet().length != values.length)
        ? 'حداقل دو گزینه غیرتکراری وارد کنید.'
        : null);
    if (!formKey.currentState!.validate() || optionsError != null) return;
    Navigator.of(context).pop(WorkflowFormFieldDefinition(
      key: key.text.trim().isEmpty ? _freeKey() : key.text.trim(),
      label: label.text.trim(),
      type: widget.type,
      required: required,
      options: isChoice ? values : const [],
      defaultValue: hasDefault ? defaultValue.text.trim() : '',
      helpText: help.text.trim(),
      showInList: showInList,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final type = requestFieldTypeFor(widget.type);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar:
            AsoudHeader(title: initial == null ? 'افزودن فیلد' : 'ویرایش فیلد'),
        body: Form(
          key: formKey,
          child: ListView(padding: AsoudFormStyle.pagePadding, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AsoudIconBox(
                  icon: type.icon, color: AsoudColors.primary, size: 38),
              title: const Text('نوع فیلد',
                  style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
              subtitle: Text(type.label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AsoudColors.text,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            AsoudFormField(
                controller: label,
                label: 'عنوان فیلد *',
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  return length < 2 || length > 80
                      ? 'عنوان فیلد بین ۲ تا ۸۰ حرف باشد.'
                      : null;
                }),
            Directionality(
              textDirection: TextDirection.ltr,
              child: AsoudFormField(
                  controller: key,
                  label: 'نام فنی (اختیاری)',
                  hint: 'purchase_type',
                  enabled: initial == null,
                  validator: _validateKey),
            ),
            AsoudFormField(
                controller: help, label: 'توضیحات (اختیاری)', lines: 2),
            if (hasDefault)
              AsoudFormField(
                  controller: defaultValue,
                  label: 'مقدار پیش‌فرض (اختیاری)',
                  hint: widget.type == 'Date' ? 'YYYY-MM-DD' : null,
                  validator: _validateDefault),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('اجباری',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              value: required,
              onChanged: (value) => setState(() => required = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('نمایش در لیست',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              value: showInList,
              onChanged: (value) => setState(() => showInList = value),
            ),
            if (isChoice) ..._optionEditors(),
          ]),
        ),
        bottomNavigationBar:
            AsoudBottomActions(primaryLabel: 'ذخیره', onPrimary: _save),
      ),
    );
  }

  List<Widget> _optionEditors() => [
        const SizedBox(height: 8),
        const Text('گزینه‌ها',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: options[index],
                  decoration: InputDecoration(
                      isDense: true, hintText: 'گزینه ${index + 1}'),
                ),
              ),
              IconButton(
                tooltip: 'حذف گزینه',
                onPressed: () => setState(() {
                  options.removeAt(index).dispose();
                }),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AsoudColors.danger),
              ),
            ]),
          ),
        if (optionsError != null)
          Text(optionsError!,
              style: const TextStyle(fontSize: 11, color: AsoudColors.danger)),
        OutlinedButton.icon(
          onPressed: () => setState(() => options.add(TextEditingController())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('افزودن گزینه'),
        ),
      ];
}
