import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/offline/offline_failure.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'editor_design_step.dart';
import 'editor_field_sheet.dart';
import 'editor_info_step.dart';
import 'editor_preview_step.dart';
import 'editor_rules_step.dart';
import 'editor_widgets.dart';

export 'editor_design_step.dart';
export 'editor_field_sheet.dart';
export 'editor_info_step.dart';
export 'editor_preview_step.dart';
export 'editor_rules_step.dart';
export 'editor_widgets.dart';

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
  late FormMap schema = migrateFormSchema(formMap(record['schema']));
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

  Widget metadata() => EditorInfoStep(
        schema: schema,
        options: options,
        change: change,
      );

  Widget design() => EditorDesignStep(
        schema: schema,
        change: change,
        onEditField: editField,
      );

  Widget rules() => EditorRulesStep(
        schema: schema,
        change: change,
      );

  Widget previewStep() => EditorPreviewStep(
        schema: schema,
        record: record,
        options: options,
        preview: preview,
        previewKey: previewKey,
        repository: widget.repository,
        busy: busy,
        change: change,
        save: save,
        onPreviewChanged: (v) => setState(() => preview = v),
        onError: (e) => setState(() => error = e),
        onNotice: (n) => setState(() => notice = n),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (popped, result) async {
          if (popped) {
            return;
          }
          if (await formConfirm(
            context,
            'تغییرات ذخیره‌نشده وجود دارد. خارج می‌شوید؟',
          )) {
            if (context.mounted) {
              Navigator.pop(context);
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
