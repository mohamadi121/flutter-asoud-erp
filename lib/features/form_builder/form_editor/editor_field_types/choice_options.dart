import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../../form_runtime/schema_migration.dart';

Widget? buildChoiceOptionsConfig(FormMap f) {
  if (!['Select', 'MultiSelect'].contains(f['type'])) {
    return null;
  }
  return TextFormField(
    initialValue: choiceOptions(f).map((option) => option['label']).join('\n'),
    maxLines: 4,
    decoration: const InputDecoration(
      labelText: 'گزینه‌ها؛ هر خط یک گزینه',
    ),
    onChanged: (v) => f['options'] = updateChoiceOptions(f, v),
  );
}
