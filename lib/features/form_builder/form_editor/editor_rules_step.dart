import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_widgets.dart';

class EditorRulesStep extends StatelessWidget {
  const EditorRulesStep({
    required this.schema,
    required this.change,
    super.key,
  });

  final FormMap schema;
  final void Function(VoidCallback fn) change;

  @override
  Widget build(BuildContext context) {
    final rows = formMaps(schema['rules']);
    final fields = {for (final f in schemaFields(schema)) f['key']: f['label']};

    Future<void> edit([int? index]) async {
      final rule = await editSchemaRule(
        context,
        schema,
        index == null ? null : rows[index],
      );
      if (rule != null && context.mounted) {
        change(() {
          index == null ? rows.add(rule) : rows[index] = rule;
          schema['rules'] = rows;
        });
      }
    }

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: schemaFields(schema).isEmpty ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('افزودن قانون'),
        ),
        for (var i = 0; i < rows.length; i++)
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    '${fields[rows[i]['target']] ?? 'فیلد حذف‌شده'} · ${{
                      'visible': 'نمایش شرطی',
                      'required': 'اجباری',
                      'readonly': 'فقط‌خواندنی',
                    }[rows[i]['action']]}',
                  ),
                  subtitle: Text(
                    '${formMaps(rows[i]['conditions']).length} شرط',
                  ),
                  value: rows[i]['enabled'] != false,
                  onChanged: (v) => change(() {
                    rows[i]['enabled'] = v;
                    schema['rules'] = rows;
                  }),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => edit(i),
                      child: const Text('ویرایش'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await formConfirm(context, 'قانون حذف شود؟') &&
                            context.mounted) {
                          change(() {
                            rows.removeAt(i);
                            schema['rules'] = rows;
                          });
                        }
                      },
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Text(
          'قوانین هم‌نوع یک فیلد با «یا» ترکیب می‌شوند. فیلد مخفی در ثبت ارسال نمی‌شود؛ فیلد فقط‌خواندنی مقدار پیش‌فرض معتبر دارد.',
        ),
      ],
    );
  }
}

Widget _conditionInput(
  BuildContext context,
  FormMap? field,
  dynamic value,
  ValueChanged<dynamic> change,
) {
  final type = field?['type'];
  if (['Boolean', 'Checkbox'].contains(type)) {
    return formSelect(
      'مقدار مقایسه',
      value?.toString(),
      const {'true': 'بله', 'false': 'خیر'},
      change,
    );
  }
  if (['Select', 'MultiSelect'].contains(type)) {
    return formSelect(
      'مقدار مقایسه',
      value?.toString(),
      {
        for (final option in choiceOptions(field ?? {}) )
          '${option['id']}': '${option['label']}',
      },
      change,
    );
  }
  if (['Date', 'DateTime', 'Time'].contains(type)) {
    return ListTile(
      title: const Text('مقدار مقایسه'),
      subtitle: Text(
        value == null
            ? 'انتخاب تاریخ یا ساعت'
            : type == 'Time'
                ? '$value'
                : formatJalaliDateTimeIso('$value'),
      ),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        DateTime? date;
        if (type != 'Time') {
          date = await showAsoudJalaliPicker(
            context,
            initialDate: DateTime.tryParse('$value'),
          );
          if (date == null || !context.mounted) {
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
            change(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            );
            return;
          }
          date = DateTime(
            date!.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        }
        change(
          type == 'Date'
              ? date!.toIso8601String().substring(0, 10)
              : date!.toIso8601String(),
        );
      },
    );
  }
  final numeric =
      ['Integer', 'Decimal', 'Money', 'Formula', 'Rating'].contains(type);
  return TextFormField(
    key: ValueKey('condition:${field?['key']}'),
    initialValue: '${value ?? ''}',
    decoration: const InputDecoration(labelText: 'مقدار مقایسه'),
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    onChanged: (v) => change(numeric ? toLatinDigits(v) : v),
  );
}

Future<FormMap?> editSchemaRule(
  BuildContext context,
  FormMap schema,
  FormMap? original,
) {
  final rule = copyForm(
    original ??
        {
          'id': newFormId(),
          'action': 'visible',
          'join': 'and',
          'enabled': true,
          'conditions': [
            {'op': 'eq'},
          ],
        },
  );
  final fields = schemaFields(schema),
      labels = {for (final f in fields) '${f['key']}': '${f['label']}'};
  return formSheet<FormMap>(
    context,
    'قانون فرم',
    (sheet, update) => Column(
      children: [
        formSelect(
          'فیلد مقصد',
          rule['target'] as String?,
          labels,
          (v) => update(() => rule['target'] = v),
        ),
        formSelect(
          'اقدام',
          rule['action'] as String?,
          const {
            'visible': 'نمایش شرطی',
            'required': 'اجباری شدن',
            'readonly': 'فقط‌خواندنی',
          },
          (v) => update(() => rule['action'] = v),
        ),
        formSelect(
          'رابطه شرط‌ها',
          rule['join'] as String?,
          const {
            'and': 'همه شرط‌ها (و)',
            'or': 'حداقل یکی (یا)',
          },
          (v) => update(() => rule['join'] = v),
        ),
        for (var i = 0; i < formMaps(rule['conditions']).length; i++)
          Builder(
            builder: (_) {
              final conditions = formMaps(rule['conditions']),
                  c = conditions[i];
              void set(String key, dynamic value) => update(() {
                    c[key] = value;
                    conditions[i] = c;
                    rule['conditions'] = conditions;
                  });
              final source =
                  fields.where((f) => f['key'] == c['field']).firstOrNull;
              final operators = {...formOps}..removeWhere(
                  (key, value) =>
                      ['gt', 'lt', 'ge', 'le'].contains(key) &&
                      ![
                        'Integer',
                        'Decimal',
                        'Money',
                        'Formula',
                        'Rating',
                        'Date',
                        'Time',
                        'DateTime',
                      ].contains(source?['type']),
                );
              operators.removeWhere(
                (key, _) =>
                    (source?['type'] == 'Table' &&
                        !['empty', 'not_empty'].contains(key)) ||
                    (source?['type'] == 'MultiSelect' &&
                        !['empty', 'not_empty', 'contains'].contains(key)) ||
                    (key == 'contains' &&
                        !['Text', 'LongText', 'Barcode', 'MultiSelect']
                            .contains(source?['type'])),
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      formSelect(
                        'فیلد شرط ${i + 1}',
                        c['field'] as String?,
                        labels,
                        (v) {
                          set('field', v);
                          final kind =
                              fields.firstWhere((f) => f['key'] == v)['type'];
                          set(
                            'op',
                            kind == 'Table'
                                ? 'empty'
                                : kind == 'MultiSelect'
                                    ? 'contains'
                                    : 'eq',
                          );
                          set('value', null);
                        },
                      ),
                      formSelect(
                        'عملگر',
                        c['op'] as String?,
                        operators,
                        (v) => set('op', v),
                      ),
                      if (!['empty', 'not_empty'].contains(c['op']))
                        _conditionInput(
                          sheet,
                          source,
                          c['value'],
                          (v) => set('value', v),
                        ),
                      IconButton(
                        onPressed: conditions.length <= 1
                            ? null
                            : () => update(() {
                                  conditions.removeAt(i);
                                  rule['conditions'] = conditions;
                                }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        OutlinedButton(
          onPressed: () => update(
            () => rule['conditions'] = [
              ...formMaps(rule['conditions']),
              {'op': 'eq'},
            ],
          ),
          child: const Text('افزودن شرط'),
        ),
        FilledButton(
          onPressed: () {
            final candidate = {
              ...schema,
              'rules': [
                ...formMaps(schema['rules'])
                    .where((r) => r['id'] != rule['id']),
                rule,
              ],
            };
            final errors = schemaProblems(candidate);
            if (rule['target'] == null ||
                formMaps(rule['conditions']).any(
                  (c) =>
                      c['field'] == null ||
                      (!['empty', 'not_empty'].contains(c['op']) &&
                          isEmptyValue(c['value'])),
                ) ||
                errors.isNotEmpty) {
              ScaffoldMessenger.of(sheet).showSnackBar(
                SnackBar(
                  content: Text(
                    errors.isEmpty
                        ? 'فیلدهای قانون را انتخاب کنید.'
                        : errors.join('\n'),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(sheet, rule);
          },
          child: const Text('ذخیره قانون'),
        ),
      ],
    ),
  );
}
