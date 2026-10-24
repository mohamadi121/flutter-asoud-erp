import 'package:flutter/material.dart';

import '../../core/utils/failure_message.dart';
import 'execution_contract.dart';
import 'form_repository.dart';

/// Shared request-form and workflow-step parameter controls.
class ExecutionSettings extends StatefulWidget {
  const ExecutionSettings(
      {required this.repository,
      required this.onChanged,
      this.schema,
      this.fields,
      this.showKind = true,
      super.key});
  final FormRepository repository;
  final FormMap? schema;
  final List<FormMap>? fields;
  final bool showKind;
  final VoidCallback onChanged;
  @override
  State<ExecutionSettings> createState() => _ExecutionSettingsState();
}

class _ExecutionSettingsState extends State<ExecutionSettings> {
  List<FormMap> catalog = [];
  bool loading = true, canRetry = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load().ignore();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.repository.executionKinds();
      if (mounted) setState(() => catalog = data);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = failureMessage(failure);
          canRetry = failureCanRetry(failure);
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<FormMap> get fields =>
      widget.fields ??
      [
        for (final section in (widget.schema?['sections'] as List? ?? []))
          for (final field in (section['fields'] as List? ?? []))
            field as FormMap,
      ];

  void update(VoidCallback work) {
    setState(work);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget.schema;
    final kind = formMap(schema?['execution'])['kind'];
    final selected =
        catalog.where((entry) => entry['kind'] == kind).firstOrNull;
    final parameters = <String, dynamic>{};
    for (final entry
        in schema == null ? catalog : [if (selected != null) selected]) {
      parameters.addAll(formMap(entry['parameters']));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      const Text('اجرای پس از تأیید',
          style: TextStyle(fontWeight: FontWeight.bold)),
      if (loading)
        const Text('در حال دریافت انواع اجرا…')
      else if (error != null) ...[
        Text(error!),
        if (canRetry)
          TextButton(
              onPressed: () => load().ignore(),
              child: const Text('تلاش دوباره')),
      ] else if (catalog.isEmpty)
        const Text('هنوز نوع اجرایی در دسترس نیست.')
      else ...[
        if (schema != null && widget.showKind)
          DropdownButtonFormField<String>(
            key: const ValueKey('execution-kind'),
            initialValue: selected == null ? '' : '$kind',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع اجرا'),
            items: [
              const DropdownMenuItem(value: '', child: Text('بدون اجرا')),
              for (final entry in catalog)
                DropdownMenuItem(
                    value: '${entry['kind']}',
                    child: Text('${entry['label']}',
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: (value) => update(() {
              if (value == null || value.isEmpty) {
                schema.remove('execution');
              } else {
                schema['execution'] = {'kind': value};
              }
              for (final field in fields) {
                field.remove('execution_key');
              }
            }),
          ),
        if (kind != null && selected == null)
          const Text('نوع اجرای ذخیره‌شده در دسترس نیست.'),
        if (schema == null || selected != null)
          for (final field in fields) _picker(field, parameters),
        if (schema != null && selected != null)
          for (final problem in executionProblems(schema, catalog))
            Text(problem),
      ],
      const SizedBox(height: 12),
    ]);
  }

  Widget _picker(FormMap field, Map<String, dynamic> parameters) {
    final allFields = widget.schema == null
        ? fields
        : [
            for (final section in (widget.schema!['sections'] as List? ?? []))
              for (final item in (section['fields'] as List? ?? []))
                item as FormMap,
          ];
    final used = {
      for (final other in allFields)
        if (other['key'] != field['key']) other['execution_key']
    };
    final choices = <String, String>{
      '': 'بدون نگاشت',
      for (final entry in parameters.entries)
        if (executionTypeMatches(
                '${field['type']}', entry.value['types'] as List) &&
            !used.contains(entry.key))
          entry.key: '${entry.value['label']}'
    };
    final value = '${field['execution_key'] ?? ''}';
    return KeyedSubtree(
        key: ValueKey('execution-parameter-${field['key']}'),
        child: DropdownButtonFormField<String>(
          key: ValueKey('${field['type']}:$value'),
          initialValue: choices.containsKey(value) ? value : '',
          isExpanded: true,
          decoration:
              InputDecoration(labelText: 'پارامتر اجرا · ${field['label']}'),
          items: [
            for (final entry in choices.entries)
              DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (next) => update(() {
            if (next == null || next.isEmpty) {
              field.remove('execution_key');
            } else {
              field['execution_key'] = next;
            }
          }),
        ));
  }
}
