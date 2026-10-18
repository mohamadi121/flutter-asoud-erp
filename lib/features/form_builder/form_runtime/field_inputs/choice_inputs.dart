import 'package:flutter/material.dart';

import '../../form_repository.dart';

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
    final options = (f['options'] as List? ?? []).cast<String>();
    return DropdownButtonFormField<String>(
      key: ValueKey('$key:$value'),
      initialValue: options.contains(value) ? value as String : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text('${formMap(f['option_labels'])[o] ?? o}'),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => required && v == null ? 'انتخاب الزامی است.' : null,
    );
  }
  if (type == 'MultiSelect') {
    final selected = (value as List? ?? []).toList();
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
              for (final option in f['options'] as List? ?? [])
                FilterChip(
                  label: Text('$option'),
                  selected: selected.contains(option),
                  onSelected: (active) {
                    active ? selected.add(option) : selected.remove(option);
                    onChanged(selected);
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
