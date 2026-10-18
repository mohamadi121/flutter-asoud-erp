import 'package:flutter/material.dart';

import '../../../core/utils/jalali_date.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_field_types/choice_options.dart';
import 'editor_field_types/date_time.dart';
import 'editor_field_types/file.dart';
import 'editor_field_types/formula.dart';
import 'editor_field_types/link.dart';
import 'editor_field_types/table.dart';
import 'editor_field_types/text_number.dart';
import 'editor_widgets.dart';

Future<FormMap?> editSchemaField(
  BuildContext context,
  FormMap schema,
  FormMap original, {
  bool column = false,
  String? parentNative,
}) async {
  final f = copyForm(original);
  return formSheet<FormMap>(
    context,
    column ? 'تنظیم ستون' : 'تنظیم فیلد',
    (sheet, update) {
      void set(String key, dynamic value) => update(() => f[key] = value);
      Widget text(
        String label,
        String key, {
        bool numeric = false,
        int lines = 1,
      }) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: ValueKey(key),
              initialValue: '${f[key] ?? ''}',
              maxLines: lines,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    )
                  : TextInputType.text,
              decoration: InputDecoration(labelText: label),
              onChanged: (v) {
                if (numeric && v.trim().isEmpty) {
                  f.remove(key);
                } else {
                  f[key] = numeric ? num.tryParse(toLatinDigits(v)) : v;
                }
              },
            ),
          );

      final fieldOptions = {
        for (final field in schemaFields(
          schema,
        ).where((v) => v['key'] != f['key']))
          '${field['key']}': '${field['label']}',
      };
      final choiceConfig = buildChoiceOptionsConfig(f);
      final linkSourceConfig = buildLinkSourceConfig(f, set);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text('عنوان *', 'label'),
          formSelect(
            'نوع فیلد',
            '${f['type']}',
            {
              ...formTypes,
            }..removeWhere((key, value) => column && key == 'Table'),
            (v) => set('type', v),
          ),
          SwitchListTile(
            title: const Text('الزامی'),
            value: f['required'] == true,
            onChanged: (v) => set('required', v),
          ),
          if (choiceConfig != null) choiceConfig,
          if (linkSourceConfig != null) linkSourceConfig,
          ...buildTableConfig(
            context: sheet,
            f: f,
            schema: schema,
            set: set,
            onEditColumn: editSchemaField,
          ),
          ...buildFormulaConfig(
            f: f,
            schema: schema,
            fieldOptions: fieldOptions,
            set: set,
          ),
          ExpansionTile(
            title: const Text('تنظیمات بیشتر'),
            children: [
              Text('شناسه پایدار: ${f['key']}'),
              text('راهنما', 'help'),
              formSelect(
                'منبع مقدار پیش‌فرض',
                '${f['default_source'] ?? ''}',
                {
                  '': 'مقدار ثابت یا خالی',
                  if (f['type'] == 'Date') 'today': 'تاریخ امروز',
                  if (['Text', 'Display'].contains(f['type'])) ...{
                    'user': 'کاربر ثبت‌کننده',
                    'company': 'دفتر جاری',
                  },
                  if (f['type'] == 'Link' && f['source'] == 'Employee')
                    'employee': 'پرسنل مرتبط با کاربر',
                  if (f['type'] == 'Link' && f['source'] == 'Department')
                    'department': 'واحد پرسنل ثبت‌کننده',
                },
                (v) => set('default_source', v),
              ),
              ...buildLinkAdvancedConfig(
                f: f,
                fieldOptions: fieldOptions,
                set: set,
                update: update,
              ),
              if (['Boolean', 'Checkbox'].contains(f['type']))
                SwitchListTile(
                  title: const Text('پیش‌فرض: بله'),
                  value: f['default'] == true,
                  onChanged: (v) => set('default', v),
                )
              else if (![
                'Table',
                'MultiSelect',
                'File',
                'Image',
                'Signature',
                'Formula',
              ].contains(f['type']))
                text('مقدار پیش‌فرض', 'default'),
              SwitchListTile(
                title: const Text('فقط‌خواندنی'),
                value: f['readonly'] == true,
                onChanged: (v) => set('readonly', v),
              ),
              ...buildTextNumberConfig(f, set),
              ...buildDateTimeConfig(
                context: sheet,
                f: f,
                set: set,
                update: update,
              ),
              ...buildFileConfig(f, set),
              if (schema['kind'] == 'Document' || parentNative != null)
                formSelect(
                  'فیلد مقصد سند',
                  f['native_key'] as String?,
                  nativeFieldLabels(parentNative ?? '${schema['target']}'),
                  (v) => set('native_key', v),
                ),
              if (formMaps(schema['workflow_fields']).isNotEmpty)
                formSelect(
                  'فیلد مقصد گردش‌کار',
                  f['workflow_key'] as String?,
                  {
                    '': 'بدون نگاشت',
                    for (final target in formMaps(schema['workflow_fields']))
                      '${target['key']}': '${target['label']}',
                  },
                  (v) => set('workflow_key', v),
                ),
            ],
          ),
          FilledButton(
            onPressed: () {
              if ('${f['label'] ?? ''}'.trim().isEmpty) {
                ScaffoldMessenger.of(sheet).showSnackBar(
                  const SnackBar(content: Text('عنوان را وارد کنید.')),
                );
                return;
              }
              Navigator.pop(sheet, f);
            },
            child: const Text('ذخیره فیلد'),
          ),
        ],
      );
    },
  );
}
