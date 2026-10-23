import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../schema_migration.dart';

Widget? buildChoiceInput({
  required BuildContext context,
  required FormMap f,
  required dynamic value,
  required String label,
  required bool required,
  required ValueChanged<dynamic> onChanged,
}) {
  final type = '${f['type']}';
  final key = '${f['key']}';

  if (type == 'Checkbox') {
    return CheckboxListTile(
      title: Text(label),
      value: value == true,
      onChanged: (checked) => onChanged(checked ?? false),
    );
  }
  if (type == 'Boolean') {
    return SwitchListTile(
      title: Text(label),
      value: value == true,
      onChanged: onChanged,
    );
  }
  if (type == 'Select') {
    final options = choiceOptions(f);
    final selectedId = choiceOptionId(f, value) ?? '$value';
    final selectedExists = options.any((option) => option['id'] == selectedId);
    if (f['style'] == 'radio') {
      return FormField<String>(
        initialValue: value is String ? selectedId : null,
        validator: (v) => required && v == null ? 'انتخاب الزامی است.' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            for (final option in options)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('${option['label']}'),
                value: '${option['id']}',
                groupValue: selectedId,
                onChanged: (id) {
                  state.didChange(id);
                  onChanged(id);
                },
              ),
            if (state.hasError)
              Text(state.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('$key:$value'),
      initialValue: value is String ? selectedId : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (value != null && !selectedExists)
          DropdownMenuItem(
            value: selectedId,
            child: const Text(deletedChoiceOptionLabel),
          ),
        ...options.map(
            (option) => DropdownMenuItem(
              value: '${option['id']}',
              child: Text('${option['label']}'),
            ),
          ),
      ],
      onChanged: onChanged,
      validator: (v) => required && v == null ? 'انتخاب الزامی است.' : null,
    );
  }
  if (type == 'MultiSelect') {
    final selected = (value as List? ?? [])
        .map((item) => choiceOptionId(f, item) ?? item)
        .toList();
    final options = choiceOptions(f);
    final knownIds = options.map((option) => option['id']).toSet();
    return FormField<List>(
      initialValue: selected,
      validator: (_) =>
          required && selected.isEmpty ? 'انتخاب الزامی است.' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Wrap(
            spacing: 6,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text('${option['label']}'),
                  selected: selected.contains(option['id']),
                  onSelected: (active) {
                    active ? selected.add(option['id']) : selected.remove(option['id']);
                    onChanged(selected);
                  },
                ),
              for (final id in selected.where((id) => !knownIds.contains(id)))
                FilterChip(
                  label: const Text(deletedChoiceOptionLabel),
                  selected: true,
                  onSelected: (active) {
                    if (!active) {
                      selected.remove(id);
                      onChanged(selected);
                    }
                  },
                ),
            ],
          ),
          if (state.hasError)
            Text(
              state.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
  return null;
}
