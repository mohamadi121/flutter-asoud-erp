import 'package:flutter/material.dart';

import '../../../../core/utils/failure_message.dart';
import '../../../form_builder/form_repository.dart';

/// Selects a published definition only; never submits a form or creates a record.
class ActionResultFormPicker extends StatefulWidget {
  const ActionResultFormPicker({required this.repository, super.key});
  final FormRepository repository;
  @override
  State<ActionResultFormPicker> createState() => _ActionResultFormPickerState();
}

class _ActionResultFormPickerState extends State<ActionResultFormPicker> {
  List<FormMap> rows = [];
  String query = '';
  String? error;
  bool loading = true, selecting = false;
  @override
  void initState() {
    super.initState();
    load();
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
    if (selecting) return;
    setState(() {
      selecting = true;
      error = null;
    });
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
        Navigator.pop(context, {
          'form': result['name'],
          'revision': result['revision'],
          'schema': result['schema']
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = failureDetail(failure));
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
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
}
