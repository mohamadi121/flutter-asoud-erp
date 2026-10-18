import 'package:flutter/material.dart';

import '../form_repository.dart';
import 'editor_widgets.dart';

class EditorInfoStep extends StatelessWidget {
  const EditorInfoStep({
    required this.schema,
    required this.options,
    required this.change,
    super.key,
  });

  final FormMap schema;
  final FormMap options;
  final void Function(VoidCallback fn) change;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          formSelect(
            'نوع فرم',
            '${schema['kind']}',
            const {
              'Request': 'درخواست',
              'Document': 'سند',
            },
            (v) => change(() => schema['kind'] = v),
          ),
          TextFormField(
            initialValue: '${schema['title'] ?? ''}',
            decoration: const InputDecoration(labelText: 'عنوان فرم *'),
            onChanged: (v) => change(() => schema['title'] = v),
          ),
          const SizedBox(height: 12),
          formSelect(
            'ماژول *',
            '${schema['module']}',
            formModules,
            (v) => change(() => schema['module'] = v),
          ),
          TextFormField(
            initialValue: '${schema['description'] ?? ''}',
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'توضیح کوتاه'),
            onChanged: (v) => change(() => schema['description'] = v),
          ),
          if (schema['kind'] == 'Document') ...[
            formSelect(
              'نوع سند استاندارد *',
              schema['target'] as String?,
              const {
                'Journal Entry': 'سند حسابداری',
                'Material Request': 'درخواست کالا',
              },
              (v) => change(() => schema['target'] = v),
            ),
            const Text(
              'فیلدها به اطلاعات سند نگاشت می‌شوند. قواعد اصلی سند تغییر نمی‌کنند و ثبت، پیش‌نویس سند می‌سازد.',
            ),
          ],
          if (schema['kind'] == 'Request')
            ExpansionTile(
              title: const Text('اتصال به گردش‌کار (اختیاری)'),
              children: [
                formSelect(
                  'گردش‌کار آماده',
                  '${schema['workflow'] ?? ''}',
                  {
                    '': 'بدون گردش‌کار؛ فقط ثبت فرم',
                    for (final workflow in formMaps(options['workflows']))
                      '${workflow['name']}': '${workflow['title']}',
                  },
                  (value) => change(() {
                    schema['workflow'] = value;
                    schema['workflow_fields'] = formMaps(options['workflows'])
                            .where((w) => w['name'] == value)
                            .firstOrNull?['fields'] ??
                        [];
                  }),
                ),
                const Text(
                  'پس از انتخاب، فیلدهای فرم را در تنظیمات بیشتر هر فیلد به ورودی‌های گردش‌کار نگاشت کنید. مجوز و اعتبارسنجی درخواست اصلی حفظ می‌شود.',
                ),
              ],
            ),
          TextFormField(
            initialValue: '${schema['category'] ?? ''}',
            decoration: const InputDecoration(labelText: 'زیرگروه (اختیاری)'),
            onChanged: (v) => change(() => schema['category'] = v),
          ),
          formSelect(
            'نمایش بخش‌ها',
            '${schema['layout'] ?? 'sections'}',
            const {
              'sections': 'بخش‌های بازشونده',
              'tabs': 'تب‌های قابل پیمایش',
            },
            (v) => change(() => schema['layout'] = v),
          ),
        ],
      );
}
