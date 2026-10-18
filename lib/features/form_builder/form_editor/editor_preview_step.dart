import 'package:flutter/material.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../../../core/utils/jalali_date.dart';
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
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('پیش‌نمایش فرم'),
          children: [
            Form(
              key: previewKey,
              child: FormFieldsView(
                schema: schema,
                values: preview,
                repository: repository,
                onChanged: onPreviewChanged,
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final problems = schemaProblems(schema);
                previewKey.currentState?.validate();
                if (problems.isEmpty && repository.client.isAuthenticated) {
                  try {
                    await repository.call('get_validation', {
                      'company': repository.company,
                      'schema': schema,
                    });
                    if (context.mounted) {
                      onNotice(
                        'ساختار، قواعد و نگاشت در سرور بررسی شدند. مقادیر آزمایشی ثبت نشدند.',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      onError(offlineFailureMessage(e));
                    }
                  }
                  return;
                }
                onNotice(
                  problems.isEmpty
                      ? 'بررسی ساختار محلی انجام شد؛ سرور هنگام انتشار و ثبت دوباره بررسی می‌کند.'
                      : problems.join('\n'),
                );
              },
              child: const Text('بررسی فرم'),
            ),
          ],
        ),
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
}
