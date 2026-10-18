import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';
import '../../../core/widgets/asoud_jalali_picker.dart';
import '../../../core/offline/offline_failure.dart';
import '../form_repository.dart';
import 'formula_engine.dart';
import 'rules_engine.dart';

const formTypes = <String, String>{
  'Text': 'متن کوتاه',
  'LongText': 'متن بلند',
  'Integer': 'عدد صحیح',
  'Decimal': 'عدد اعشاری',
  'Money': 'مبلغ',
  'Date': 'تاریخ',
  'Time': 'ساعت',
  'DateTime': 'تاریخ و ساعت',
  'Select': 'انتخاب تکی',
  'MultiSelect': 'انتخاب چندگانه',
  'Boolean': 'بله / خیر',
  'Checkbox': 'چک‌باکس',
  'Link': 'اطلاعات سیستم',
  'Table': 'جدول',
  'Formula': 'محاسبات',
  'Display': 'متن نمایشی',
  'Rating': 'امتیاز',
  'File': 'فایل',
  'Image': 'تصویر',
  'Signature': 'تصویر امضا',
  'Barcode': 'بارکد / QR (ورود کد)',
};
const formSources = <String, String>{
  'Employee': 'پرسنل',
  'Customer': 'مشتری',
  'Supplier': 'تأمین‌کننده',
  'Item': 'کالا',
  'Warehouse': 'انبار',
  'Account': 'حساب',
  'Cost Center': 'مرکز هزینه',
  'Project': 'پروژه',
  'Department': 'واحد سازمانی',
};
const formOps = <String, String>{
  'eq': 'برابر',
  'ne': 'نابرابر',
  'gt': 'بزرگ‌تر',
  'lt': 'کوچک‌تر',
  'ge': 'بزرگ‌تر یا مساوی',
  'le': 'کوچک‌تر یا مساوی',
  'empty': 'خالی است',
  'not_empty': 'خالی نیست',
  'contains': 'شامل',
};
const formulaOps = <String, String>{
  'add': 'جمع',
  'subtract': 'تفریق',
  'multiply': 'ضرب',
  'divide': 'تقسیم',
  'percent': 'درصد',
  'sum': 'جمع ستون',
  'sum_product': 'جمع حاصل‌ضرب ستون‌ها',
  'average': 'میانگین ستون',
  'count': 'تعداد ردیف',
};
const formLinkFilters = <String, Map<String, String>>{
  'Employee': {'department': 'واحد سازمانی'},
  'Item': {'item_group': 'گروه کالا'},
  'Customer': {'customer_group': 'گروه مشتری'},
  'Supplier': {'supplier_group': 'گروه تأمین‌کننده'},
  'Account': {'account_type': 'نوع حساب'},
  'Warehouse': {'parent_warehouse': 'انبار والد'},
  'Cost Center': {'parent_cost_center': 'مرکز هزینه والد'},
  'Project': {'status': 'وضعیت'},
  'Department': {'parent_department': 'واحد والد'},
};

class FormFieldsView extends StatelessWidget {
  const FormFieldsView({
    required this.schema,
    required this.values,
    required this.onChanged,
    required this.repository,
    this.formName,
    this.enabled = true,
    this.snapshot = false,
    super.key,
  });
  final FormMap schema, values;
  final ValueChanged<FormMap> onChanged;
  final FormRepository repository;
  final String? formName;
  final bool enabled;
  final bool snapshot;

  @override
  Widget build(BuildContext context) {
    final computed = snapshot ? values : evaluatedValues(schema, values);
    final sections = formMaps(schema['sections']);
    Widget sectionView(FormMap section) => Card(
          child: ExpansionTile(
            key: ValueKey(section['id']),
            initiallyExpanded: true,
            title: Text('${section['title'] ?? ''}'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              for (final field in formMaps(section['fields']))
                if (formFlag(field, schema, computed, 'visible'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _input(context, field, computed),
                  ),
            ],
          ),
        );
    if (schema['layout'] == 'tabs' && sections.length > 1) {
      return DefaultTabController(
          length: sections.length,
          child: Builder(builder: (context) {
            final tabs = DefaultTabController.of(context);
            return Column(children: [
              TabBar(isScrollable: true, tabs: [
                for (final section in sections) Tab(text: '${section['title']}')
              ]),
              AnimatedBuilder(
                  animation: tabs,
                  builder: (context, child) =>
                      sectionView(sections[tabs.index]))
            ]);
          }));
    }
    return Column(children: sections.map(sectionView).toList());
  }

  Widget _input(BuildContext context, FormMap f, FormMap computed) {
    final key = '${f['key']}', type = '${f['type']}', v = computed[key];
    final required = formFlag(f, schema, computed, 'required');
    final label = '${f['label']}${required ? ' *' : ''}';
    final editable = enabled && !formFlag(f, schema, computed, 'readonly');
    void set(dynamic value) => onChanged({...computed, key: value});
    if (type == 'Formula' ||
        type == 'Display' ||
        (!editable && type != 'Table')) {
      final text = ['Date', 'DateTime'].contains(type) && !isEmptyValue(v)
          ? formatJalaliDateTimeIso('$v')
          : ['Boolean', 'Checkbox'].contains(type)
              ? (v == true ? 'بله' : 'خیر')
              : '${v ?? ''}';
      return ListTile(title: Text(label), subtitle: Text(text));
    }
    if (type == 'Checkbox') {
      return CheckboxListTile(
          title: Text(label),
          value: v == true,
          onChanged: (checked) => set(checked ?? false));
    }
    if (type == 'Boolean') {
      return SwitchListTile(
        title: Text(label),
        value: v == true,
        onChanged: set,
      );
    }
    if (type == 'Select') {
      final options = (f['options'] as List? ?? []).cast<String>();
      return DropdownButtonFormField<String>(
        key: ValueKey('$key:$v'),
        initialValue: options.contains(v) ? v as String : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((o) => DropdownMenuItem(
                value: o,
                child: Text('${formMap(f['option_labels'])[o] ?? o}')))
            .toList(),
        onChanged: set,
        validator: (v) => required && v == null ? 'انتخاب الزامی است.' : null,
      );
    }
    if (type == 'MultiSelect') {
      final selected = (v as List? ?? []).toList();
      return FormField<List>(
        initialValue: selected,
        validator: (_) =>
            required && selected.isEmpty ? 'انتخاب الزامی است.' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Wrap(
              spacing: 6,
              children: [
                for (final option in f['options'] as List? ?? [])
                  FilterChip(
                    label: Text('$option'),
                    selected: selected.contains(option),
                    onSelected: (active) {
                      active ? selected.add(option) : selected.remove(option);
                      set(selected);
                    },
                  ),
              ],
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    if (type == 'Table') {
      final rows = formMaps(v);
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
                      set(rows);
                    },
                  ),
                  if (editable)
                    TextButton.icon(
                      onPressed: () {
                        rows.removeAt(i);
                        set(rows);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف ردیف'),
                    ),
                ],
              ),
            ),
          if (editable)
            OutlinedButton.icon(
              onPressed:
                  rows.length >= ((f['max_rows'] as num?)?.toInt() ?? 100)
                      ? null
                      : () => set([...rows, <String, dynamic>{}]),
              icon: const Icon(Icons.add),
              label: const Text('افزودن ردیف'),
            ),
        ],
      );
    }
    if (type == 'Date' || type == 'Time' || type == 'DateTime') {
      final date = DateTime.tryParse('$v');
      final display = date == null
          ? '${v ?? 'انتخاب'}'
          : '${JalaliDate.fromDateTime(date).format()}${type == 'DateTime' ? ' ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : ''}';
      return FormField<dynamic>(
        validator: (_) =>
            required && isEmptyValue(v) ? 'انتخاب الزامی است.' : null,
        builder: (state) => ListTile(
          title: Text(label),
          subtitle: Text(state.errorText ?? display),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            DateTime? picked;
            if (type != 'Time') {
              picked = await showAsoudJalaliPicker(context, initialDate: date);
              if (picked == null || !context.mounted) {
                return;
              }
            }
            if (type != 'Date') {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time == null) {
                return;
              }
              if (type == 'Time') {
                set(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                );
                return;
              }
              picked = DateTime(
                picked!.year,
                picked.month,
                picked.day,
                time.hour,
                time.minute,
              );
            }
            set(
              type == 'Date'
                  ? picked!.toIso8601String().substring(0, 10)
                  : picked!.toIso8601String(),
            );
          },
        ),
      );
    }
    if (type == 'Link') {
      return ListTile(
        title: Text(label),
        subtitle: Text('${v ?? 'انتخاب از اطلاعات مجاز'}'),
        trailing: const Icon(Icons.search),
        onTap: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            useSafeArea: true,
            builder: (_) => _LinkPicker(
              repository: repository,
              source: '${f['source']}',
              formName: formName,
              filterField: formMap(f['link_filter'])['field'] as String?,
              filterValue: computed[formMap(f['link_filter'])['value_field']],
            ),
          );
          if (result != null) {
            set(result);
          }
        },
      );
    }
    if (['File', 'Image', 'Signature'].contains(type)) {
      return Column(
        children: [
          ListTile(
            title: Text(label),
            subtitle: Text('${v ?? 'فایل انتخاب نشده'}'),
            trailing: v == null
                ? null
                : IconButton(
                    onPressed: () => set(null),
                    icon: const Icon(Icons.close),
                  ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('انتخاب فایل خصوصی'),
            onPressed: () async {
              try {
                final maxFiles = (f['max_files'] as num?)?.toInt() ?? 1;
                final result = await FilePicker.platform.pickFiles(
                  withData: true,
                  allowMultiple: maxFiles > 1,
                  type: FileType.custom,
                  allowedExtensions: (f['extensions'] as List? ??
                          (type == 'File'
                              ? ['pdf', 'jpg', 'png']
                              : ['jpg', 'jpeg', 'png']))
                      .cast<String>(),
                );
                if (result == null ||
                    result.files.any((f) => f.bytes == null)) {
                  return;
                }
                if (result.files.length > maxFiles ||
                    result.files
                            .fold<int>(0, (size, file) => size + file.size) >
                        25 * 1024 * 1024) {
                  throw StateError(
                      'تعداد یا مجموع حجم فایل‌ها بیش از حد مجاز است.');
                }
                if (result.files.any((file) =>
                    file.size > ((f['max_mb'] as num?) ?? 10) * 1024 * 1024)) {
                  throw StateError('حجم فایل بیش از حد مجاز است.');
                }
                final names = <String>[];
                for (final file in result.files) {
                  if (formName == null) {
                    names.add('پیش‌نمایش محلی: ${file.name}');
                    continue;
                  }
                  final uploaded =
                      formMap(await repository.call('upload_file', {
                    'form': formName,
                    'filename': file.name,
                    'content': base64Encode(file.bytes!),
                  }));
                  names.add('${uploaded['name']}');
                }
                if (context.mounted) {
                  set(maxFiles > 1 ? names : names.single);
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(offlineFailureMessage(error))),
                  );
                }
              }
            },
          ),
        ],
      );
    }
    final numeric = ['Integer', 'Decimal', 'Money', 'Rating'].contains(type);
    return _ControlledFormText(
      key: ValueKey(key),
      value: '${v ?? ''}',
      decoration: InputDecoration(
        labelText: label,
        helperText: '${f['help'] ?? ''}',
      ),
      maxLines: type == 'LongText' ? 3 : 1,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      onChanged: (value) => set(numeric ? toLatinDigits(value) : value),
      validator: (value) {
        if (required && (value ?? '').trim().isEmpty) {
          return 'تکمیل این فیلد الزامی است.';
        }
        if ((value ?? '').isEmpty) {
          return null;
        }
        if (numeric) {
          final n = double.tryParse(toLatinDigits(value!));
          if (n == null ||
              !n.isFinite ||
              (type == 'Integer' && n != n.roundToDouble())) {
            return 'عدد معتبر وارد کنید.';
          }
          if (f['min'] != null && n < formNumber(f['min'])) {
            return 'کمتر از حداقل مجاز است.';
          }
          if (f['max'] != null && n > formNumber(f['max'])) {
            return 'بیشتر از حداکثر مجاز است.';
          }
        }
        if (value!.length < ((f['min_length'] as num?)?.toInt() ?? 0) ||
            value.length > ((f['max_length'] as num?)?.toInt() ?? 5000)) {
          return 'طول متن مجاز نیست.';
        }
        if (f['format'] == 'email') {
          final parts = value.split('@');
          if (parts.length != 2 ||
              parts.first.isEmpty ||
              !parts.last.contains('.') ||
              parts.last.split('.').any((v) => v.isEmpty) ||
              RegExp(r'\s').hasMatch(value)) {
            return '${f['error_message'] ?? 'ایمیل معتبر وارد کنید.'}';
          }
        }
        if (f['format'] == 'mobile' &&
            !RegExp(r'^09[0-9]{9}$').hasMatch(toLatinDigits(value))) {
          return '${f['error_message'] ?? 'شماره همراه معتبر وارد کنید.'}';
        }
        return null;
      },
    );
  }
}

class _ControlledFormText extends StatefulWidget {
  const _ControlledFormText(
      {required this.value,
      required this.decoration,
      required this.maxLines,
      required this.keyboardType,
      required this.onChanged,
      required this.validator,
      super.key});
  final String value;
  final InputDecoration decoration;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String> validator;
  @override
  State<_ControlledFormText> createState() => _ControlledFormTextState();
}

class _ControlledFormTextState extends State<_ControlledFormText> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _ControlledFormText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      validator: widget.validator);
}

class _LinkPicker extends StatefulWidget {
  const _LinkPicker({
    required this.repository,
    required this.source,
    this.formName,
    this.filterField,
    this.filterValue,
  });
  final FormRepository repository;
  final String source;
  final String? formName;
  final String? filterField;
  final dynamic filterValue;
  @override
  State<_LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends State<_LinkPicker> {
  late Future<List<FormMap>> rows;
  @override
  void initState() {
    super.initState();
    rows = load('');
  }

  Future<List<FormMap>> load(String query) async => formMaps(
        await widget.repository.call('get_link_options', {
          'company': widget.repository.company,
          'source': widget.source,
          'query': query,
          'form': widget.formName,
          'filter_field': widget.filterField,
          'filter_value': widget.filterValue,
        }),
      );
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'جست‌وجو و تأیید',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (q) => setState(() => rows = load(q)),
                ),
                Expanded(
                  child: FutureBuilder<List<FormMap>>(
                    future: rows,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(offlineFailureMessage(snapshot.error!));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView(
                        children: [
                          for (final r in snapshot.data!)
                            ListTile(
                              title: Text('${r['label']}'),
                              subtitle: Text('${r['name']}'),
                              onTap: () =>
                                  Navigator.pop(context, '${r['name']}'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بستن'),
                ),
              ],
            ),
          ),
        ),
      );
}
