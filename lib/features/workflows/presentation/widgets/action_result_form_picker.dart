import 'package:flutter/material.dart';

import '../../../../core/utils/failure_message.dart';
import '../../../form_builder/form_repository.dart';

/// Selects a published definition only; never submits a form or creates a record.
class ActionResultFormPicker extends StatefulWidget {
  const ActionResultFormPicker({required this.repository, this.inline = false,
      this.enabled = true, this.selected, this.onSelected, this.onBusyChanged, super.key});
  final FormRepository repository;
  final bool inline, enabled;
  final FormMap? selected;
  final ValueChanged<FormMap>? onSelected;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<ActionResultFormPicker> createState() => _ActionResultFormPickerState();
}

class _ActionResultFormPickerState extends State<ActionResultFormPicker> {
  final selectionText = TextEditingController();
  List<FormMap> rows = [];
  String query = '';
  String? error;
  bool loading = true, selecting = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    selectionText.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.repository.list('Request'),
        widget.repository.list('Document')
      ]);
      if (mounted) {
        setState(() => rows = result
            .expand((items) => items)
            .where((row) =>
                row['status'] == 'Published' &&
                row['removed'] != true &&
                row['local'] != true &&
                row['cached'] != true)
            .toList());
      }
    } catch (failure) {
      if (mounted) setState(() => error = failureDetail(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choose(FormMap row) async {
    if (selecting || !widget.enabled) return;
    setState(() {
      selecting = true;
      error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final identity = row['builtin_pending'] == true
          ? formMap(await widget.repository.call('open_builtin', {
              'company': widget.repository.company,
              'key': row['builtin_key'],
              'manage': 1
            }))
          : row;
      if (identity['active_revision'] is! String ||
          '${identity['active_revision']}'.isEmpty) {
        throw StateError(
            'فرم هنوز نسخهٔ منتشرشده ندارد؛ ابتدا در فرم‌ساز منتشر کنید.');
      }
      final result = formMap(await widget.repository.call('get_form', {
        'name': identity['name'],
        'manage': 1,
        'revision_name': identity['active_revision']
      }));
      if (result['disabled'] == true ||
          result['name'] is! String ||
          result['revision'] is! String ||
          result['revision'] != result['active_revision']) {
        throw StateError('این فرم منتشرشده و فعال نیست؛ فهرست را تازه کنید.');
      }
      if (mounted) {
        final selection = <String, dynamic>{
          'form': result['name'],
          'revision': result['revision'],
          'schema': result['schema']
        };
        if (widget.inline) {
          FocusScope.of(context).unfocus();
          widget.onSelected?.call(selection);
        } else {
          Navigator.pop(context, selection);
        }
      }
    } catch (failure) {
      if (mounted) {
        if (widget.inline) {
          final previous = rows.where((row) => row['name'] == widget.selected?['form']).firstOrNull;
          selectionText.text = previous?['title']?.toString() ?? '';
        }
        setState(() => error = failureDetail(failure));
      }
    } finally {
      if (mounted) {
        setState(() => selecting = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.inline ? _inlinePicker() : Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * .75 -
                  MediaQuery.viewInsetsOf(context).bottom)
              .clamp(240.0, MediaQuery.sizeOf(context).height * .75),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const ListTile(
                    title: Text('انتخاب فرم ثبت نتیجه'),
                    subtitle: Text(
                        'فقط فرم‌های منتشرشده؛ بدون ایجاد درخواست یا سند تازه')),
                TextField(
                    onChanged: selecting
                        ? null
                        : (value) => setState(() => query = value.trim()),
                    decoration: const InputDecoration(
                        hintText: 'جست‌وجوی نام فرم…',
                        prefixIcon: Icon(Icons.search))),
                if (loading || selecting) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                Expanded(
                    child: ListView(children: [
                  for (final row in rows
                      .where((row) => '${row['title'] ?? ''}'.contains(query)))
                    ListTile(
                        title: Text('${row['title'] ?? 'فرم بدون عنوان'}'),
                        leading: const Icon(Icons.description_outlined),
                        onTap: selecting ? null : () => choose(row)),
                  if (!loading && rows.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'فرم قابل استفاده‌ای وجود ندارد؛ ابتدا در فرم‌ساز یک فرم را منتشر کنید.')),
                ])),
                TextButton(
                    onPressed: loading || selecting ? null : load,
                    child: const Text('دریافت دوباره')),
              ]))));

  Widget _inlinePicker() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (loading || selecting) const LinearProgressIndicator(),
    LayoutBuilder(builder: (context, constraints) => DropdownMenu<String>(
      controller: selectionText,
      key: ValueKey('action-result-form-${widget.selected?['form']}-${widget.selected?['revision']}-${rows.length}'),
      width: constraints.maxWidth,
      menuHeight: 240,
      menuStyle: MenuStyle(backgroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      enabled: widget.enabled && !loading && !selecting,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      initialSelection: rows.any((row) => row['name'] == widget.selected?['form'])
          ? (widget.selected?['form'] as String?) : null,
      hintText: 'انتخاب یا جست‌وجوی فرم…',
      textStyle: const TextStyle(fontSize: 12),
      dropdownMenuEntries: [for (final row in rows)
        DropdownMenuEntry(value: '${row['name']}', label: '${row['title'] ?? 'فرم بدون عنوان'}')],
      onSelected: (name) {
        final row = rows.where((row) => row['name'] == name).firstOrNull;
        if (row != null) choose(row).ignore();
      },
    )),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 11))),
    if (!loading && rows.isEmpty) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('فرم منتشرشده‌ای در دسترس نیست؛ ابتدا فرم را در فرم‌ساز منتشر کنید.',
            style: TextStyle(fontSize: 11))),
    if (error != null || (!loading && rows.isEmpty)) TextButton(
        onPressed: !widget.enabled || loading || selecting ? null : load, child: const Text('دریافت دوباره')),
  ]);
}
