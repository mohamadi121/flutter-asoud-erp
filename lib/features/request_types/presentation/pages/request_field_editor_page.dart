import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/presentation/widgets/request_custom_table.dart';
import '../../domain/request_type_catalog.dart';

/// A field and its table columns are saved together; cancel never mutates the builder.
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
  late String selectedType = initial?.type ?? widget.type;
  late final label = TextEditingController(text: initial?.label ?? '');
  late final technicalKey = TextEditingController(text: initial?.key ?? '');
  late final help = TextEditingController(text: initial?.helpText ?? '');
  late final defaultValue =
      TextEditingController(text: initial?.defaultValue ?? '');
  late final options =
      TextEditingController(text: initial?.options.join('\n') ?? '');
  late final columns = [
    for (final column
        in initial?.columns ?? const <WorkflowFormFieldDefinition>[])
      _ColumnDraft(column),
  ];
  final retired = <_ColumnDraft>[];
  late bool required = initial?.required ?? false;
  late bool showInList = initial?.showInList ?? false;
  String? columnsError;

  bool get isChoice =>
      selectedType == 'Choice' || selectedType == 'Multi Choice';
  bool get hasDefault =>
      !requestFieldTypesWithoutDefault.contains(selectedType);
  List<String> get optionValues => options.text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  @override
  void dispose() {
    for (final controller in [
      label,
      technicalKey,
      help,
      defaultValue,
      options
    ]) {
      controller.dispose();
    }
    for (final column in [...columns, ...retired]) {
      column.dispose();
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

  String? _validateTitle(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 80 ? 'عنوان بین ۲ تا ۸۰ حرف باشد.' : null;
  }

  String? _validateKey(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!requestFieldKeyPattern.hasMatch(text)) {
      return 'حروف کوچک انگلیسی، عدد و _؛ شروع با حرف (حداقل ۲ نویسه)';
    }
    return widget.takenKeys.contains(text) ? 'این نام فنی تکراری است.' : null;
  }

  String? _validateDefault(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 140) return 'حداکثر ۱۴۰ نویسه وارد کنید.';
    if (selectedType == 'Number' || selectedType == 'Currency') {
      final number = num.tryParse(text);
      if (number == null || !number.isFinite) return 'عدد معتبر وارد کنید.';
    }
    if (selectedType == 'Date') return asoudDateValidator(text);
    if (isChoice && !optionValues.contains(text)) {
      return 'یکی از گزینه‌ها را وارد کنید.';
    }
    return null;
  }

  void _addColumn() {
    var index = 1;
    final keys = {
      ...columns.map((column) => column.key),
      ...retired.map((column) => column.key)
    };
    while (keys.contains('column_$index')) {
      index++;
    }
    setState(() => columns.add(_ColumnDraft(WorkflowFormFieldDefinition(
        key: 'column_$index', label: '', type: 'Short Text'))));
  }

  void _save() {
    final settingsError = _validateKey(technicalKey.text) ??
        (hasDefault ? _validateDefault(defaultValue.text) : null);
    if (settingsError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(settingsError)));
      return;
    }
    setState(() => columnsError = selectedType == 'Table' && columns.isEmpty
        ? 'حداقل یک ستون برای جدول اضافه کنید.'
        : null);
    if (!formKey.currentState!.validate() || columnsError != null) return;
    Navigator.of(context).pop(WorkflowFormFieldDefinition(
      key: technicalKey.text.trim().isEmpty
          ? _freeKey()
          : technicalKey.text.trim(),
      label: label.text.trim(),
      type: selectedType,
      required: required,
      options: isChoice ? optionValues : const [],
      defaultValue: hasDefault ? defaultValue.text.trim() : '',
      helpText: help.text.trim(),
      showInList: showInList,
      columns: selectedType == 'Table'
          ? columns.map((column) => column.value).toList()
          : const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      for (final name in [
        'Short Text',
        'Number',
        'Date',
        'Choice',
        'Attachment',
        'Table'
      ])
        requestFieldTypeFor(name),
      for (final type in requestFieldTypes)
        if (!['Short Text', 'Number', 'Date', 'Choice', 'Attachment', 'Table']
            .contains(type.type))
          type,
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
            title: initial == null ? 'افزودن فیلد جدید' : 'ویرایش فیلد'),
        body: Form(
            key: formKey,
            child: ListView(padding: AsoudFormStyle.pagePadding, children: [
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final type in types)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Semantics(
                            selected: selectedType == type.type,
                            child: InkWell(
                              onTap: initial != null || !type.supported
                                  ? null
                                  : () => setState(() {
                                        selectedType = type.type;
                                        defaultValue.clear();
                                        columnsError = null;
                                      }),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                  width: 62,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 3),
                                  decoration: BoxDecoration(
                                      color: selectedType == type.type
                                          ? AsoudColors.primary
                                              .withValues(alpha: .07)
                                          : AsoudColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: selectedType == type.type
                                              ? AsoudColors.primary
                                              : AsoudColors.border)),
                                  child: Column(children: [
                                    Icon(type.icon,
                                        size: 22,
                                        color: selectedType == type.type
                                            ? AsoudColors.primary
                                            : AsoudColors.muted),
                                    const SizedBox(height: 5),
                                    Text(type.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: selectedType == type.type
                                                ? AsoudColors.primary
                                                : AsoudColors.text)),
                                  ])),
                            )),
                      ),
                  ])),
              if (initial != null)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        'نوع فیلد ثبت‌شده برای حفظ اطلاعات قبلی ثابت است.',
                        style:
                            TextStyle(fontSize: 10, color: AsoudColors.muted))),
              const SizedBox(height: 20),
              AsoudFormField(
                  controller: label,
                  label: 'عنوان فیلد *',
                  hint: 'مثلاً اقلام درخواستی',
                  validator: _validateTitle),
              AsoudFormField(
                  controller: help,
                  label: 'توضیحات (اختیاری)',
                  lines: 2,
                  validator: (value) => (value?.length ?? 0) > 200
                      ? 'حداکثر ۲۰۰ نویسه وارد کنید.'
                      : null),
              if (selectedType == 'Table') ..._tableEditors(),
              if (isChoice)
                AsoudFormField(
                    controller: options,
                    label: 'گزینه‌ها (هر گزینه در یک خط)',
                    lines: 4,
                    validator: (_) => optionValues.length < 2 ||
                            optionValues.toSet().length != optionValues.length
                        ? 'حداقل دو گزینه غیرتکراری وارد کنید.'
                        : null),
              if (selectedType == 'Item Table')
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'این جدول به کالاها و واحدهای ERP متصل است و ستون‌های استاندارد دارد. برای ستون‌های دلخواه «جدول قابل‌تعریف» را انتخاب کنید.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AsoudColors.muted,
                            height: 1.7))),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('تنظیمات بیشتر',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                children: [
                  AsoudFormField(
                      controller: technicalKey,
                      label: 'نام فنی (اختیاری)',
                      hint: 'purchase_type',
                      enabled: initial == null,
                      validator: _validateKey),
                  if (hasDefault)
                    AsoudFormField(
                        controller: defaultValue,
                        label: 'مقدار پیش‌فرض (اختیاری)',
                        hint: selectedType == 'Date' ? 'YYYY-MM-DD' : null,
                        validator: _validateDefault),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نمایش در لیست',
                          style: TextStyle(fontSize: 12)),
                      value: showInList,
                      onChanged: (value) => setState(() => showInList = value)),
                ],
              ),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تکمیل این فیلد الزامی است',
                      style: TextStyle(fontSize: 12)),
                  value: required,
                  onChanged: (value) => setState(() => required = value)),
            ])),
        bottomNavigationBar: Directionality(
            textDirection: TextDirection.ltr,
            child: AsoudBottomActions(
                primaryLabel: initial == null ? 'ثبت فیلد' : 'ذخیره تغییرات',
                onPrimary: _save,
                secondaryLabel: 'انصراف',
                onSecondary: () => Navigator.of(context).pop())),
      ),
    );
  }

  List<Widget> _tableEditors() => [
        const Text('ستون‌های جدول',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('ستون‌ها را اضافه کنید؛ برای تغییر ترتیب، دستگیره را بکشید.',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 10),
        ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: columns.length,
            onReorderItem: (from, to) =>
                setState(() => columns.insert(to, columns.removeAt(from))),
            itemBuilder: (context, index) {
              final column = columns[index];
              return Container(
                  key: ValueKey(column.key),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AsoudColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AsoudColors.border)),
                  child: Column(children: [
                    Row(children: [
                      ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.drag_indicator_rounded,
                                  size: 18, color: AsoudColors.muted))),
                      Expanded(
                          child: TextFormField(
                              controller: column.label,
                              decoration: const InputDecoration(
                                  hintText: 'نام ستون', isDense: true),
                              style: const TextStyle(fontSize: 11),
                              validator: _validateTitle,
                              onChanged: (_) => setState(() {}))),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 88,
                          child: DropdownButtonFormField<String>(
                              initialValue: column.type,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8)),
                              items: [
                                for (final type in requestTableColumnTypes)
                                  DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                          requestFieldTypeFor(type).label,
                                          style: const TextStyle(fontSize: 10),
                                          overflow: TextOverflow.ellipsis))
                              ],
                              onChanged: column.existing
                                  ? null
                                  : (value) =>
                                      setState(() => column.type = value!))),
                      IconButton(
                          tooltip: 'حذف ستون',
                          onPressed: () => setState(
                              () => retired.add(columns.removeAt(index))),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 19, color: AsoudColors.danger)),
                    ]),
                    Row(children: [
                      const Text('الزامی',
                          style: TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                      Switch(
                          value: column.required,
                          onChanged: (value) =>
                              setState(() => column.required = value)),
                    ]),
                    if (column.type == 'Choice')
                      TextFormField(
                          controller: column.options,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              hintText: 'گزینه‌ها؛ هر گزینه در یک خط',
                              isDense: true),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (_) => setState(() {}),
                          validator: (_) => column.value.options.length < 2 ||
                                  column.value.options.toSet().length !=
                                      column.value.options.length
                              ? 'حداقل دو گزینه غیرتکراری لازم است.'
                              : null),
                  ]));
            }),
        if (columnsError != null)
          Text(columnsError!,
              style: const TextStyle(fontSize: 11, color: AsoudColors.danger)),
        TextButton.icon(
            style: TextButton.styleFrom(
                backgroundColor: AsoudColors.primary.withValues(alpha: .06)),
            onPressed: columns.length >= 12 ? null : _addColumn,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('افزودن ستون جدید')),
        const SizedBox(height: 24),
        const Text('پیش‌نمایش فیلد',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('این پیش‌نمایش ذخیره نمی‌شود.',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 10),
        ExcludeFocus(
            child: IgnorePointer(
                child: RequestCustomTable(
          key: ValueKey(Object.hashAll(columns.map((column) => column.value))),
          field: WorkflowFormFieldDefinition(
              key: 'preview_table',
              label: '',
              type: 'Table',
              columns: columns.map((column) => column.value).toList()),
          preview: true,
          onChanged: (_) {},
        ))),
      ];
}

class _ColumnDraft {
  _ColumnDraft(WorkflowFormFieldDefinition field)
      : source = field,
        key = field.key,
        type = field.type,
        required = field.required,
        existing = field.label.isNotEmpty,
        label = TextEditingController(text: field.label),
        options = TextEditingController(text: field.options.join('\n'));
  final String key;
  final WorkflowFormFieldDefinition source;
  final bool existing;
  String type;
  bool required;
  final TextEditingController label, options;
  WorkflowFormFieldDefinition get value => source.copyWith(
      label: label.text.trim(),
      type: type,
      required: required,
      options: type == 'Choice'
          ? options.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList()
          : const []);
  void dispose() {
    label.dispose();
    options.dispose();
  }
}
