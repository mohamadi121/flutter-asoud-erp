import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/asoud_ui.dart';
import '../../core/offline/offline_failure.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/widgets/asoud_jalali_picker.dart';
import 'form_repository.dart';
import 'form_runtime.dart';

const formModules = {
  'General': 'عمومی',
  'HR': 'منابع انسانی',
  'Finance': 'مالی',
  'Purchase': 'خرید',
  'Sales': 'فروش',
  'Stock': 'انبار',
  'Manufacturing': 'تولید',
  'Projects': 'پروژه‌ها',
  'IT': 'فناوری اطلاعات',
};
FormMap blankSchema(String kind) => {
      'format': 1,
      'kind': kind,
      'title': '',
      'module': 'General',
      'description': '',
      'sections': [
        {'id': 'main', 'title': 'اطلاعات اصلی', 'fields': <FormMap>[]},
      ],
      'rules': <FormMap>[],
      'access': {'mode': 'all', 'roles': [], 'departments': []},
    };

Future<T?> formSheet<T>(
  BuildContext context,
  String title,
  Widget Function(BuildContext, StateSetter) content,
) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * .85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    content(sheet, update),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

Widget formSelect(
  String label,
  String? value,
  Map<String, String> options,
  ValueChanged<String> change,
) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            change(v);
          }
        },
      ),
    );

Future<String?> formText(
  BuildContext context,
  String title,
  String initial,
) async {
  var value = initial;
  return formSheet<String>(
    context,
    title,
    (sheet, update) => Column(
      children: [
        TextFormField(initialValue: initial, onChanged: (v) => value = v),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.pop(sheet, value.trim()),
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
}

Future<bool> formConfirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأیید عملیات'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    ) ??
    false;

class FormEditorPage extends StatefulWidget {
  const FormEditorPage({
    required this.repository,
    required this.initial,
    super.key,
  });
  final FormRepository repository;
  final FormMap initial;
  @override
  State<FormEditorPage> createState() => _FormEditorPageState();
}

class _FormEditorPageState extends State<FormEditorPage> {
  late FormMap record = copyForm(widget.initial);
  late FormMap schema = formMap(record['schema']);
  FormMap preview = {}, options = {};
  String? error, notice;
  int step = 0;
  bool busy = false, dirty = false;
  Timer? autosave;
  final previewKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    record.putIfAbsent('client_id', newFormId);
    loadOptions();
  }

  Future<void> loadOptions() async {
    try {
      final data = formMap(
        await widget.repository.call('get_options', {
          'company': widget.repository.company,
        }),
      );
      if (mounted) {
        setState(() => options = data);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'فهرست نقش و واحد در دسترس نیست؛ پیش‌نویس محلی قابل ذخیره است.',
        );
      }
    }
  }

  @override
  void dispose() {
    autosave?.cancel();
    super.dispose();
  }

  void change(VoidCallback update) {
    setState(() {
      update();
      dirty = true;
      error = null;
    });
    autosave?.cancel();
    autosave = Timer(const Duration(milliseconds: 600), () async {
      try {
        await widget.repository.keepDraft({...record, 'schema': schema});
      } catch (e) {
        if (mounted) {
          setState(() => error = offlineFailureMessage(e));
        }
      }
    });
  }

  Future<void> save([String? action]) async {
    autosave?.cancel();
    final problems = schemaProblems(schema);
    if (problems.isNotEmpty) {
      setState(() => error = problems.join('\n'));
      return;
    }
    if (action != null &&
        !await formConfirm(
          context,
          action == 'publish'
              ? 'این نسخه برای کاربران مجاز فعال شود؟ ثبت‌های قبلی تغییر نمی‌کنند.'
              : 'فرم برای بررسی مدیر سیستم ارسال شود؟',
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.save({
        ...record,
        'schema': schema,
      });
      if (!mounted) {
        return;
      }
      record = result;
      if (action != null && result['local'] == true) {
        throw StateError(
          'پیش‌نویس روی دستگاه ذخیره شد؛ انتشار یا ارسال برای تأیید به اتصال سرور نیاز دارد.',
        );
      }
      if (action != null) {
        record = {
          ...formMap(
            await widget.repository.call('transition', {
              'name': record['name'],
              'action': action,
              'expected_version': record['draft_version'],
              'note': schema['change_note'] ?? '',
            }),
          ),
          'client_id': record['client_id'],
        };
      }
      if (mounted) {
        setState(() {
          dirty = false;
          notice = record['local'] == true
              ? 'پیش‌نویس روی این دستگاه ذخیره شد؛ انتشار انجام نشده است.'
              : 'اطلاعات در سرور ذخیره شد.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = offlineFailureMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> editField(FormMap section, [int? index]) async {
    final fields = formMaps(section['fields']);
    final result = await editSchemaField(
      context,
      schema,
      index == null
          ? {'key': 'f_${newFormId()}', 'label': '', 'type': 'Text'}
          : fields[index],
    );
    if (result == null || !mounted) {
      return;
    }
    change(() {
      index == null ? fields.add(result) : fields[index] = result;
      section['fields'] = fields;
    });
  }

  Widget metadata() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          formSelect(
              'نوع فرم',
              '${schema['kind']}',
              const {
                'Request': 'درخواست',
                'Document': 'سند',
              },
              (v) => change(() => schema['kind'] = v)),
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
                (v) => change(() => schema['target'] = v)),
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
                          schema['workflow_fields'] =
                              formMaps(options['workflows'])
                                      .where((w) => w['name'] == value)
                                      .firstOrNull?['fields'] ??
                                  [];
                        })),
                const Text(
                    'پس از انتخاب، فیلدهای فرم را در تنظیمات بیشتر هر فیلد به ورودی‌های گردش‌کار نگاشت کنید. مجوز و اعتبارسنجی درخواست اصلی حفظ می‌شود.'),
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
                'tabs': 'تب‌های قابل پیمایش'
              },
              (v) => change(() => schema['layout'] = v)),
        ],
      );

  Widget design() {
    final sections = formMaps(schema['sections']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final title = await formText(context, 'عنوان بخش جدید', '');
            if (title == null || title.isEmpty || !mounted) {
              return;
            }
            change(
              () => schema['sections'] = [
                ...sections,
                {'id': newFormId(), 'title': title, 'fields': <FormMap>[]},
              ],
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('افزودن بخش'),
        ),
        for (var si = 0; si < sections.length; si++)
          Card(
            child: ExpansionTile(
              key: ValueKey(sections[si]['id']),
              initiallyExpanded: true,
              title: Text('${sections[si]['title']}'),
              childrenPadding: const EdgeInsets.all(10),
              children: [
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final title = await formText(
                          context,
                          'نام بخش',
                          '${sections[si]['title']}',
                        );
                        if (title != null && title.isNotEmpty && mounted) {
                          change(() {
                            sections[si]['title'] = title;
                            schema['sections'] = sections;
                          });
                        }
                      },
                      child: const Text('تغییر نام'),
                    ),
                    IconButton(
                      tooltip: 'بخش بالاتر',
                      onPressed: si == 0
                          ? null
                          : () => change(() {
                                final s = sections.removeAt(si);
                                sections.insert(si - 1, s);
                                schema['sections'] = sections;
                              }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'بخش پایین‌تر',
                      onPressed: si == sections.length - 1
                          ? null
                          : () => change(() {
                                final s = sections.removeAt(si);
                                sections.insert(si + 1, s);
                                schema['sections'] = sections;
                              }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    TextButton(
                      onPressed: sections.length < 2
                          ? null
                          : () async {
                              if (!await formConfirm(
                                    context,
                                    'بخش حذف و فیلدهای آن به بخش دیگری منتقل شوند؟',
                                  ) ||
                                  !mounted) {
                                return;
                              }
                              change(() {
                                final removed = sections.removeAt(si);
                                final target = sections.first;
                                target['fields'] = [
                                  ...formMaps(target['fields']),
                                  ...formMaps(removed['fields']),
                                ];
                                schema['sections'] = sections;
                              });
                            },
                      child: const Text('حذف و انتقال فیلدها'),
                    ),
                  ],
                ),
                for (var fi = 0;
                    fi < formMaps(sections[si]['fields']).length;
                    fi++)
                  _fieldRow(sections, si, fi),
                OutlinedButton.icon(
                  onPressed: () async {
                    schema['sections'] = sections;
                    await editField(sections[si]);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن فیلد'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fieldRow(List<FormMap> sections, int si, int fi) {
    final fields = formMaps(sections[si]['fields']), f = fields[fi];
    return ListTile(
      title: Text('${f['label']}'),
      subtitle: Text(formTypes[f['type']] ?? ''),
      onTap: () async {
        schema['sections'] = sections;
        await editField(sections[si], fi);
      },
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'delete' &&
              !await formConfirm(context, 'فیلد و قوانین وابسته حذف شوند؟')) {
            return;
          }
          if (!mounted) {
            return;
          }
          change(() {
            if (action == 'delete') {
              fields.removeAt(fi);
              schema['rules'] = formMaps(schema['rules'])
                  .where(
                    (r) =>
                        r['target'] != f['key'] &&
                        !formMaps(r['conditions'])
                            .any((c) => c['field'] == f['key']),
                  )
                  .toList();
            }
            if (action == 'copy') {
              fields.insert(fi + 1, {
                ...copyForm(f),
                'key': 'f_${newFormId()}',
                'label': '${f['label']} (کپی)',
                'native_key': null,
              });
            }
            if (action == 'up' && fi > 0) {
              fields.insert(fi - 1, fields.removeAt(fi));
            }
            if (action == 'down' && fi < fields.length - 1) {
              fields.insert(fi + 1, fields.removeAt(fi));
            }
            if (action.startsWith('move:')) {
              final target = sections.firstWhere(
                (s) => s['id'] == action.substring(5),
              );
              target['fields'] = [
                ...formMaps(target['fields']),
                fields.removeAt(fi),
              ];
            }
            sections[si]['fields'] = fields;
            schema['sections'] = sections;
          });
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'copy', child: Text('تکثیر')),
          if (fi > 0) const PopupMenuItem(value: 'up', child: Text('بالا')),
          if (fi < fields.length - 1)
            const PopupMenuItem(value: 'down', child: Text('پایین')),
          for (final section in sections.where(
            (s) => s['id'] != sections[si]['id'],
          ))
            PopupMenuItem(
              value: 'move:${section['id']}',
              child: Text('انتقال به ${section['title']}'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    );
  }

  Widget rules() {
    final rows = formMaps(schema['rules']);
    final fields = {for (final f in schemaFields(schema)) f['key']: f['label']};
    Future<void> edit([int? index]) async {
      final rule = await editSchemaRule(
        context,
        schema,
        index == null ? null : rows[index],
      );
      if (rule != null && mounted) {
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
                      'readonly': 'فقط‌خواندنی'
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
                            mounted) {
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

  Widget previewStep() {
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
                repository: widget.repository,
                onChanged: (v) => setState(() => preview = v),
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final problems = schemaProblems(schema);
                previewKey.currentState?.validate();
                if (problems.isEmpty &&
                    widget.repository.client.isAuthenticated) {
                  try {
                    await widget.repository.call('get_validation', {
                      'company': widget.repository.company,
                      'schema': schema
                    });
                    if (mounted) {
                      setState(() => notice =
                          'ساختار، قواعد و نگاشت در سرور بررسی شدند. مقادیر آزمایشی ثبت نشدند.');
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => error = offlineFailureMessage(e));
                    }
                  }
                  return;
                }
                setState(
                  () => notice = problems.isEmpty
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
                          await widget.repository.call('get_history', {
                            'name': record['name'],
                          }),
                        );
                        if (!mounted) {
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
                                        await widget.repository.call(
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
                                          repository: widget.repository,
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
                        if (mounted) {
                          setState(() => error = offlineFailureMessage(e));
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

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (popped, result) async {
          if (popped) {
            return;
          }
          try {
            await widget.repository.keepDraft({...record, 'schema': schema});
            if (context.mounted) {
              setState(() => dirty = false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() => error = offlineFailureMessage(e));
            }
          }
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: const AsoudHeader(
              title: 'فرم‌ساز آسود',
              subtitle: 'طراحی مشترک درخواست و سند',
            ),
            body: AbsorbPointer(
              absorbing: busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'مرحله ${step + 1} از ۴: ${[
                      'مشخصات فرم',
                      'طراحی فرم',
                      'قوانین فرم',
                      'پیش‌نمایش و انتشار'
                    ][step]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  LinearProgressIndicator(value: (step + 1) / 4),
                  const SizedBox(height: 16),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(notice!),
                    ),
                  [metadata, design, rules, previewStep][step](),
                  TextButton(
                    onPressed: busy ? null : () => save(),
                    child: const Text('ذخیره پیش‌نویس'),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: AsoudBottomActions(
              primaryLabel: busy
                  ? 'در حال ذخیره…'
                  : step == 3
                      ? 'ذخیره پیش‌نویس'
                      : 'مرحله بعد',
              onPrimary: busy
                  ? null
                  : () async {
                      if (step == 3) {
                        await save();
                      } else {
                        try {
                          await widget.repository
                              .keepDraft({...record, 'schema': schema});
                          if (mounted) {
                            setState(() => step++);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => error = offlineFailureMessage(e));
                          }
                        }
                      }
                    },
              secondaryLabel: step > 0 ? 'مرحله قبل' : null,
              onSecondary:
                  step > 0 && !busy ? () => setState(() => step--) : null,
            ),
          ),
        ),
      );
}

Future<FormMap?> editSchemaField(
  BuildContext context,
  FormMap schema,
  FormMap original, {
  bool column = false,
  String? parentNative,
}) async {
  final f = copyForm(original);
  return formSheet<FormMap>(context, column ? 'تنظیم ستون' : 'تنظیم فیلد', (
    sheet,
    update,
  ) {
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
                    decimal: true, signed: true)
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
    final numeric = [
      'Integer',
      'Decimal',
      'Money',
      'Rating',
    ].contains(f['type']);
    final fieldOptions = {
      for (final field in schemaFields(
        schema,
      ).where((v) => v['key'] != f['key']))
        '${field['key']}': '${field['label']}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text('عنوان *', 'label'),
        formSelect(
          'نوع فیلد',
          '${f['type']}',
          {...formTypes}..removeWhere((key, value) => column && key == 'Table'),
          (v) => set('type', v),
        ),
        SwitchListTile(
          title: const Text('الزامی'),
          value: f['required'] == true,
          onChanged: (v) => set('required', v),
        ),
        if (['Select', 'MultiSelect'].contains(f['type']))
          TextFormField(
            initialValue: (f['options'] as List? ?? []).join('\n'),
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'گزینه‌ها؛ هر خط یک گزینه',
            ),
            onChanged: (v) => f['options'] = v
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList(),
          ),
        if (f['type'] == 'Link')
          formSelect(
            'منبع اطلاعات',
            f['source'] as String?,
            formSources,
            (v) => set('source', v),
          ),
        if (f['type'] == 'Table') ...[
          for (var i = 0; i < formMaps(f['columns']).length; i++)
            ListTile(
              title: Text('${formMaps(f['columns'])[i]['label']}'),
              onTap: () async {
                final result = await editSchemaField(
                  sheet,
                  {
                    'workflow_fields': formMaps(schema['workflow_fields'])
                            .where((t) => t['key'] == f['workflow_key'])
                            .firstOrNull?['columns'] ??
                        [],
                    'sections': [
                      {'fields': f['columns']},
                    ],
                  },
                  formMaps(f['columns'])[i],
                  column: true,
                  parentNative: f['native_key'] as String?,
                );
                if (result != null && sheet.mounted) {
                  final cols = formMaps(f['columns']);
                  cols[i] = result;
                  set('columns', cols);
                }
              },
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete' &&
                      !await formConfirm(sheet, 'ستون حذف شود؟')) {
                    return;
                  }
                  final cols = formMaps(f['columns']);
                  if (v == 'delete') {
                    cols.removeAt(i);
                  } else if (v == 'up' && i > 0) {
                    cols.insert(i - 1, cols.removeAt(i));
                  } else if (v == 'down' && i < cols.length - 1) {
                    cols.insert(i + 1, cols.removeAt(i));
                  }
                  if (sheet.mounted) {
                    set('columns', cols);
                  }
                },
                itemBuilder: (_) => [
                  if (i > 0)
                    const PopupMenuItem(value: 'up', child: Text('بالا')),
                  if (i < formMaps(f['columns']).length - 1)
                    const PopupMenuItem(value: 'down', child: Text('پایین')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ),
          OutlinedButton(
            onPressed: () async {
              final result = await editSchemaField(
                sheet,
                {
                  'workflow_fields': formMaps(schema['workflow_fields'])
                          .where((t) => t['key'] == f['workflow_key'])
                          .firstOrNull?['columns'] ??
                      [],
                  'sections': [
                    {'fields': f['columns']},
                  ],
                },
                {'key': 'c_${newFormId()}', 'label': '', 'type': 'Text'},
                column: true,
                parentNative: f['native_key'] as String?,
              );
              if (result != null && sheet.mounted) {
                set('columns', [...formMaps(f['columns']), result]);
              }
            },
            child: const Text('افزودن ستون'),
          ),
          text('حداقل ردیف', 'min_rows', numeric: true),
          text('حداکثر ردیف (تا ۱۰۰)', 'max_rows', numeric: true),
        ],
        if (f['type'] == 'Formula') ...[
          formSelect(
            'محاسبه',
            formMap(f['formula'])['op'] as String?,
            formulaOps,
            (v) => set('formula', {...formMap(f['formula']), 'op': v}),
          ),
          ExpansionTile(
            title: const Text('ورودی‌های محاسبه به ترتیب انتخاب'),
            children: [
              for (final field in fieldOptions.entries)
                CheckboxListTile(
                  title: Text(field.value),
                  value: (formMap(f['formula'])['inputs'] as List? ?? [])
                      .contains(field.key),
                  onChanged: (v) {
                    final formula = formMap(f['formula']),
                        inputs = [...formula['inputs'] as List? ?? []];
                    v == true
                        ? inputs.add(field.key)
                        : inputs.remove(field.key);
                    set('formula', {...formula, 'inputs': inputs});
                  },
                ),
            ],
          ),
          formSelect(
            'جدول برای جمع یا تعداد',
            formMap(f['formula'])['table'] as String?,
            {
              for (final t in schemaFields(
                schema,
              ).where((t) => t['type'] == 'Table'))
                '${t['key']}': '${t['label']}',
            },
            (v) => set('formula', {
              ...formMap(f['formula']),
              'table': v,
              'columns': [],
            }),
          ),
          for (final t in schemaFields(
            schema,
          ).where((t) => t['key'] == formMap(f['formula'])['table']))
            Wrap(
              children: [
                for (final c in formMaps(t['columns']))
                  FilterChip(
                    label: Text('${c['label']}'),
                    selected: (formMap(f['formula'])['columns'] as List? ?? [])
                        .contains(c['key']),
                    onSelected: (active) {
                      final formula = formMap(f['formula']),
                          cols = [...formula['columns'] as List? ?? []];
                      active ? cols.add(c['key']) : cols.remove(c['key']);
                      set('formula', {...formula, 'columns': cols});
                    },
                  ),
              ],
            ),
          formSelect(
            'رقم اعشار',
            '${formMap(f['formula'])['precision'] ?? 2}',
            {for (var i = 0; i <= 8; i++) '$i': '$i'},
            (v) => set('formula', {
              ...formMap(f['formula']),
              'precision': int.parse(v),
            }),
          ),
          const Text(
            'محاسبه کلاینت پیش‌نمایش است؛ مبلغ در سرور با دقت ده‌دهی محاسبه می‌شود. تقسیم بر صفر خطا دارد.',
          ),
        ],
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
                    'company': 'دفتر جاری'
                  },
                  if (f['type'] == 'Link' && f['source'] == 'Employee')
                    'employee': 'پرسنل مرتبط با کاربر',
                  if (f['type'] == 'Link' && f['source'] == 'Department')
                    'department': 'واحد پرسنل ثبت‌کننده',
                },
                (v) => set('default_source', v)),
            if (f['type'] == 'Link') ...[
              formSelect(
                  'فیلتر وابسته منبع',
                  '${formMap(f['link_filter'])['field'] ?? ''}',
                  {'': 'بدون فیلتر', ...?formLinkFilters[f['source']]},
                  (v) => update(() {
                        if (v.isEmpty) {
                          f.remove('link_filter');
                        } else {
                          f['link_filter'] = {
                            ...formMap(f['link_filter']),
                            'field': v
                          };
                        }
                      })),
              if (f['link_filter'] != null)
                formSelect(
                    'مقدار فیلتر از فیلد',
                    formMap(f['link_filter'])['value_field'] as String?,
                    fieldOptions,
                    (v) => set('link_filter',
                        {...formMap(f['link_filter']), 'value_field': v})),
            ],
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
            if (numeric) ...[
              text('حداقل', 'min', numeric: true),
              text('حداکثر', 'max', numeric: true),
            ],
            if (['Date', 'DateTime'].contains(f['type']))
              for (final bound in ['min_date', 'max_date'])
                ListTile(
                  title: Text(
                      bound == 'min_date' ? 'حداقل تاریخ' : 'حداکثر تاریخ'),
                  subtitle: Text(f[bound] == null
                      ? 'بدون محدودیت'
                      : formatJalaliDateTimeIso('${f[bound]}')),
                  trailing: f[bound] == null
                      ? null
                      : IconButton(
                          onPressed: () => update(() => f.remove(bound)),
                          icon: const Icon(Icons.close)),
                  onTap: () async {
                    final date = await showAsoudJalaliPicker(sheet,
                        initialDate: DateTime.tryParse('${f[bound]}'));
                    if (date != null && sheet.mounted) {
                      set(bound, date.toIso8601String().substring(0, 10));
                    }
                  },
                ),
            if (['Text', 'LongText', 'Barcode'].contains(f['type'])) ...[
              text('حداقل طول', 'min_length', numeric: true),
              text('حداکثر طول', 'max_length', numeric: true),
              formSelect(
                  'قالب ورودی',
                  '${f['format'] ?? ''}',
                  const {
                    '': 'آزاد',
                    'email': 'ایمیل',
                    'mobile': 'شماره همراه ایران'
                  },
                  (v) => set('format', v)),
              text('پیام خطای قالب (اختیاری)', 'error_message'),
            ],
            if (['File', 'Image', 'Signature'].contains(f['type'])) ...[
              text('حداکثر تعداد فایل (تا ۱۰)', 'max_files', numeric: true),
              text('حداکثر حجم مگابایت (تا ۱۰)', 'max_mb', numeric: true),
              TextFormField(
                initialValue:
                    (f['extensions'] as List? ?? ['pdf', 'jpg', 'jpeg', 'png'])
                        .join(','),
                decoration: const InputDecoration(
                  labelText: 'پسوندهای مجاز با کاما',
                ),
                onChanged: (v) => f['extensions'] = v
                    .split(',')
                    .map((s) => s.trim().toLowerCase())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              ),
            ],
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
                  (v) => set('workflow_key', v)),
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
  });
}

Map<String, String> nativeFieldLabels(String target) => switch (target) {
      'Journal Entry' => {
          'voucher_type': 'نوع سند',
          'posting_date': 'تاریخ ثبت',
          'user_remark': 'شرح',
          'accounts': 'آرتیکل‌ها',
        },
      'Material Request' => {
          'material_request_type': 'نوع درخواست کالا',
          'schedule_date': 'تاریخ نیاز',
          'items': 'اقلام',
        },
      'accounts' => {
          'account': 'حساب',
          'cost_center': 'مرکز هزینه',
          'project': 'پروژه',
          'debit_in_account_currency': 'بدهکار',
          'credit_in_account_currency': 'بستانکار',
        },
      'items' => {
          'item_code': 'کالا',
          'qty': 'تعداد',
          'uom': 'واحد',
          'warehouse': 'انبار',
          'schedule_date': 'تاریخ نیاز',
          'description': 'شرح',
        },
      _ => {},
    };

Widget _conditionInput(BuildContext context, FormMap? field, dynamic value,
    ValueChanged<dynamic> change) {
  final type = field?['type'];
  if (['Boolean', 'Checkbox'].contains(type)) {
    return formSelect('مقدار مقایسه', value?.toString(),
        const {'true': 'بله', 'false': 'خیر'}, change);
  }
  if (['Select', 'MultiSelect'].contains(type)) {
    return formSelect(
        'مقدار مقایسه',
        value?.toString(),
        {
          for (final option in field?['options'] as List? ?? [])
            '$option': '${formMap(field?['option_labels'])[option] ?? option}'
        },
        change);
  }
  if (['Date', 'DateTime', 'Time'].contains(type)) {
    return ListTile(
        title: const Text('مقدار مقایسه'),
        subtitle: Text(value == null
            ? 'انتخاب تاریخ یا ساعت'
            : type == 'Time'
                ? '$value'
                : formatJalaliDateTimeIso('$value')),
        trailing: const Icon(Icons.calendar_month),
        onTap: () async {
          DateTime? date;
          if (type != 'Time') {
            date = await showAsoudJalaliPicker(context,
                initialDate: DateTime.tryParse('$value'));
            if (date == null || !context.mounted) {
              return;
            }
          }
          if (type != 'Date') {
            final time = await showTimePicker(
                context: context, initialTime: TimeOfDay.now());
            if (time == null) {
              return;
            }
            if (type == 'Time') {
              change(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
              return;
            }
            date = DateTime(
                date!.year, date.month, date.day, time.hour, time.minute);
          }
          change(type == 'Date'
              ? date!.toIso8601String().substring(0, 10)
              : date!.toIso8601String());
        });
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
      onChanged: (v) => change(numeric ? toLatinDigits(v) : v));
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
            (v) => update(() => rule['action'] = v)),
        formSelect(
            'رابطه شرط‌ها',
            rule['join'] as String?,
            const {
              'and': 'همه شرط‌ها (و)',
              'or': 'حداقل یکی (یا)',
            },
            (v) => update(() => rule['join'] = v)),
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
              operators.removeWhere((key, _) =>
                  (source?['type'] == 'Table' &&
                      !['empty', 'not_empty'].contains(key)) ||
                  (source?['type'] == 'MultiSelect' &&
                      !['empty', 'not_empty', 'contains'].contains(key)) ||
                  (key == 'contains' &&
                      !['Text', 'LongText', 'Barcode', 'MultiSelect']
                          .contains(source?['type'])));
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
                                      : 'eq');
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
                            sheet, source, c['value'], (v) => set('value', v)),
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
                formMaps(rule['conditions']).any((c) =>
                    c['field'] == null ||
                    (!['empty', 'not_empty'].contains(c['op']) &&
                        isEmptyValue(c['value']))) ||
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
