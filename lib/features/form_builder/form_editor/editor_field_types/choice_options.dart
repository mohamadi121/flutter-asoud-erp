import 'package:flutter/material.dart';

import '../../form_repository.dart';

Widget? buildChoiceOptionsConfig(FormMap f) {
  if (!['Select', 'MultiSelect'].contains(f['type'])) {
    return null;
  }
  return TextFormField(
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
  );
}
