import 'package:flutter/material.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_widgets.dart';

class EditorPreviewStep extends StatelessWidget {
  const EditorPreviewStep({
    required this.schema,
    required this.record,
    required this.options,
    required this.preview,
    required this.previewKey,
    required this.repository,
    required this.busy,
    required this.change,
    required this.save,
    required this.onPreviewChanged,
    required this.onError,
    required this.onNotice,
    super.key,
  });

  final FormMap schema;
  final FormMap record;
  final FormMap options;
  final FormMap preview;
  final GlobalKey<FormState> previewKey;
  final FormRepository repository;
  final bool busy;
  final void Function(VoidCallback fn) change;
  final Future<void> Function([String? action]) save;
  final ValueChanged<FormMap> onPreviewChanged;
  final ValueChanged<String?> onError;
  final ValueChanged<String?> onNotice;

  @override
  Widget build(BuildContext context) {
    final access = formMap(schema['access']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobilePreviewCard(context),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('مجوز استفاده'),
          children: [
            formSelect(
              'روش دسترسی',
              '${access['mode'] ?? 'all'}',
              const {
                'all': 'کاربران مجاز دفتر',
                'roles': 'نقش‌های مشخص',
                'departments': 'واحدهای مشخص',
                'and': 'نقش و واحد (هر دو)',
                'or': 'نقش یا واحد',
              },
              (v) => change(() {
                access['mode'] = v;
                schema['access'] = access;
              }),
            ),
            for (final group in ['roles', 'departments'])
              if (access['mode'] != 'all')
                ExpansionTile(
                  title: Text(group == 'roles' ? 'نقش‌ها' : 'واحدها'),
                  children: [
                    if ((options[group] as List? ?? []).isEmpty)
                      const Text(
                        'گزینه‌ای دریافت نشده است؛ اتصال و مجوز را بررسی کنید.',
                      ),
                    for (final name in options[group] as List? ?? [])
                      CheckboxListTile(
                        title: Text('$name'),
                        value: (access[group] as List? ?? []).contains(name),
                        onChanged: (selected) => change(() {
                          final chosen = [...access[group] as List? ?? []];
                          selected == true
                              ? chosen.add(name)
                              : chosen.remove(name);
                          access[group] = chosen;
                          schema['access'] = access;
                        }),
                      ),
                  ],
                ),
            const Text(
              'این انتخاب مجوزهای پایه سیستم یا محرمانگی سند را افزایش نمی‌دهد.',
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('ذخیره و انتشار'),
          children: [
            TextFormField(
              initialValue: '${schema['change_note'] ?? ''}',
              decoration: const InputDecoration(
                labelText: 'توضیح تغییرات نسخه',
              ),
              maxLength: 500,
              onChanged: (v) => change(() => schema['change_note'] = v),
            ),
            Text(
              'نسخه فعال: ${record['version'] ?? 0} — نسخه قبلی هنگام ویرایش تغییر نمی‌کند.',
            ),
            OutlinedButton(
              onPressed: busy ? null : () => save('review'),
              child: const Text('ارسال برای تأیید'),
            ),
            FilledButton(
              onPressed: busy || options['can_publish'] != true
                  ? null
                  : () => save('publish'),
              child: const Text('انتشار فرم'),
            ),
            if (options['can_publish'] != true)
              const Text('انتشار به مجوز مدیر سیستم و اتصال سرور نیاز دارد.'),
          ],
        ),
        ExpansionTile(
          title: const Text('تاریخچه نسخه‌ها'),
          children: [
            TextButton(
              onPressed: record['name'] == null
                  ? null
                  : () async {
                      try {
                        final rows = formMaps(
                          await repository.call('get_history', {
                            'name': record['name'],
                          }),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        await formSheet<void>(
                          context,
                          'تاریخچه نسخه‌ها',
                          (sheet, update) => Column(
                            children: [
                              for (final r in rows)
                                ListTile(
                                  title: Text('نسخه ${r['version']}'),
                                  subtitle: Text(
                                    '${formatJalaliDateTimeIso('${r['published_on']}')} · ${r['published_by']}\n${r['change_note'] ?? ''}',
                                  ),
                                  onTap: () async {
                                    try {
                                      final result = formMap(
                                        await repository.call(
                                          'get_form',
                                          {
                                            'name': record['name'],
                                            'manage': 1,
                                            'revision_name': r['name'],
                                          },
                                        ),
                                      );
                                      if (!sheet.mounted) {
                                        return;
                                      }
                                      await formSheet<void>(
                                        sheet,
                                        'نسخه ${r['version']} (فقط مشاهده)',
                                        (c, s) => FormFieldsView(
                                          schema: formMap(result['schema']),
                                          values: const {},
                                          repository: repository,
                                          enabled: false,
                                          onChanged: (_) {},
                                        ),
                                      );
                                    } catch (e) {
                                      if (sheet.mounted) {
                                        ScaffoldMessenger.of(sheet)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              offlineFailureMessage(e),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          onError(offlineFailureMessage(e));
                        }
                      }
                    },
              child: const Text('دریافت تاریخچه'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobilePreviewCard(BuildContext context) {
    final title =
        '${schema['title'] ?? record['title'] ?? 'درخواست خرید کالا'}';
    final module = '${schema['module'] ?? record['module'] ?? ''}';
    final subtitle =
        module.isNotEmpty ? 'نمای آزمایشی $module' : 'نمای آزمایشی پرسنل';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AsoudColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Form Header Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF3FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFF1876D2),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF122044),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AsoudColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'پیش‌نمایش',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1876D2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form fields view
          Form(
            key: previewKey,
            child: FormFieldsView(
              schema: schema,
              values: preview,
              repository: repository,
              formName: record['name'] as String?,
              onChanged: onPreviewChanged,
            ),
          ),
          const SizedBox(height: 16),

          // Bottom action bar: «نمای چاپ» and «آزمایش ثبت»
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AsoudColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormPrintPreviewPage(
                            schema: schema,
                            values: preview,
                            repository: repository,
                            formName: record['name'] as String?,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'نمای چاپ',
                      style: TextStyle(
                        color: AsoudColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1876D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      final problems = schemaProblems(schema);
                      final formValid =
                          previewKey.currentState?.validate() ?? true;

                      final tableProblems = <String>[];
                      for (final sec in formMaps(schema['sections'])) {
                        for (final f in formMaps(sec['fields'])) {
                          if (f['type'] == 'Table') {
                            final minRows = (f['min_rows'] as num?)?.toInt();
                            final rows = formMaps(preview['${f['key']}']);
                            if (minRows != null && rows.length < minRows) {
                              tableProblems.add(
                                'جدول «${f['label']}» حداقل نیازمند ${toPersianDigits(minRows)} ردیف است.',
                              );
                            }
                          }
                        }
                      }

                      if (problems.isNotEmpty ||
                          !formValid ||
                          tableProblems.isNotEmpty) {
                        final allErrors = [
                          ...problems,
                          ...tableProblems,
                          if (!formValid)
                            'لطفاً خطاهای فیلدهای فرم را برطرف کنید.',
                        ];
                        onError(allErrors.join('\n'));
                      } else {
                        onNotice(
                          'ساختار و مقادیر فرم با موفقیت در حالت آزمایشی اعتبارسنجی شدند. هیچ داده‌ای در سرور ثبت نگردید.',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_circle_down_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'آزمایش ثبت',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
