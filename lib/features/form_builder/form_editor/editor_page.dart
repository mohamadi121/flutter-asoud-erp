import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/offline/offline_failure.dart';
import '../form_repository.dart';
import '../form_runtime.dart';
import 'design/designer_header.dart';
import 'design/editor_bottom_bar.dart';
import 'design/form_spec_card.dart';
import 'design/unsaved_changes_dialog.dart';
import 'editor_design_step.dart';
import 'editor_field_sheet.dart';
import 'editor_info_step.dart';
import 'editor_preview_step.dart';
import 'editor_widgets.dart';

export 'design/designer_header.dart';
export 'design/editor_bottom_bar.dart';
export 'design/form_spec_card.dart';
export 'design/section_palette.dart';
export 'design/unsaved_changes_dialog.dart';
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
  late FormMap schema = formMap(record['schema']);
  FormMap preview = {}, options = {};
  String? error, notice;
  bool busy = false, dirty = false, previewMode = false;
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
      if (mounted) setState(() => options = data);
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
    autosave = Timer(const Duration(milliseconds: 1000), () async {
      try {
        await widget.repository.keepDraft({...record, 'schema': schema});
      } catch (e) {
        if (mounted) setState(() => error = offlineFailureMessage(e));
      }
    });
  }

  Future<bool> save([String? action]) async {
    autosave?.cancel();
    final problems = schemaProblems(schema);
    if (problems.isNotEmpty) {
      setState(() => error = problems.join('\n'));
      return false;
    }
    if (action != null &&
        !await formConfirm(
          context,
          action == 'publish'
              ? 'این نسخه برای کاربران مجاز فعال شود؟ ثبت‌های قبلی تغییر نمی‌کنند.'
              : 'فرم برای بررسی مدیر سیستم ارسال شود؟',
        )) {
      return false;
    }
    if (!mounted) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result =
          await widget.repository.save({...record, 'schema': schema});
      if (!mounted) return false;
      record = result;
      if (action != null && result['local'] == true) {
        throw StateError(
          'پیش‌نویس روی دستگاه ذخیره شد؛ انتشار یا ارسال به سرور نیاز دارد.',
        );
      }
      if (action != null) {
        record = {
          ...formMap(await widget.repository.call('transition', {
            'name': record['name'],
            'action': action,
            'expected_version': record['draft_version'],
            'note': schema['change_note'] ?? '',
          })),
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
      return true;
    } catch (e) {
      if (mounted) setState(() => error = offlineFailureMessage(e));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
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
    if (result == null || !mounted) return;
    change(() {
      index == null ? fields.add(result) : fields[index] = result;
      section['fields'] = fields;
    });
  }

  Future<void> handleBack() async {
    if (previewMode) {
      setState(() => previewMode = false);
      return;
    }
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final action = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    if (action == UnsavedChangesAction.discardAndExit) {
      Navigator.pop(context);
    } else if (action == UnsavedChangesAction.saveAndExit) {
      final success = await save();
      if (success && mounted) Navigator.pop(context);
    }
  }

  Future<void> editFormInfo() async {
    await formSheet<void>(
      context,
      'مشخصات فرم',
      (sheetCtx, _) => EditorInfoStep(
        schema: schema,
        options: options,
        change: change,
      ),
    );
  }

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
  Widget build(BuildContext context) {
    final company = widget.repository.company.isNotEmpty
        ? widget.repository.company
        : 'شرکت نمونه آسود';

    return PopScope(
      canPop: !dirty && !previewMode,
      onPopInvokedWithResult: (popped, _) async {
        if (!popped) await handleBack();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: DesignerHeader(
            title: previewMode ? 'پیش‌نمایش فرم' : 'طراحی فرم',
            subtitle: company,
            previewMode: previewMode,
            onTogglePreview: () => setState(() => previewMode = !previewMode),
            onBack: handleBack,
          ),
          body: AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (previewMode) ...[
                  previewStep(),
                  const SizedBox(height: 16),
                ] else ...[
                  FormSpecCard(
                    schema: schema,
                    record: record,
                    onEdit: editFormInfo,
                  ),
                  const SizedBox(height: 16),
                  if (error != null) _buildBanner(error!, isError: true),
                  if (notice != null) _buildBanner(notice!, isError: false),
                  EditorDesignStep(
                    schema: schema,
                    change: change,
                    onEditField: editField,
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: EditorBottomBar(
            busy: busy,
            previewMode: previewMode,
            onTogglePreview: () => setState(() => previewMode = !previewMode),
            onSave: () => save(),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(String text, {required bool isError}) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            fontSize: 12,
          ),
        ),
      );
}
