import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../field_sheet/advanced/computed/formula_advanced_config.dart';

List<Widget> buildFormulaConfig({
  required FormMap f,
  required FormMap schema,
  required Map<String, String> fieldOptions,
  required void Function(String key, dynamic value) set,
}) {
  if (f['type'] != 'Formula') {
    return const [];
  }
  return [
    FormulaAdvancedConfig(
      field: f,
      schema: schema,
      fieldOptions: fieldOptions,
      onChanged: (formula) => set('formula', formula),
    ),
  ];
}
