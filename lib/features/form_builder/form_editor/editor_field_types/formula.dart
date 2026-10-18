import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../field_sheet/advanced/computed/advanced_field_library_cards.dart';
import '../field_sheet/advanced/computed/formula_advanced_config.dart';

export '../field_sheet/advanced/computed/advanced_field_library_cards.dart';
export '../field_sheet/advanced/computed/formula_advanced_config.dart';

/// Legacy builder kept for compatibility.
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

/// Renders the complete Advanced Tab body for computed (Formula) fields,
/// including the 3 library cards in a row and the formula settings card.
Widget buildFormulaAdvancedTab({
  required FormMap f,
  required FormMap schema,
  required Map<String, String> fieldOptions,
  required void Function(String key, dynamic value) set,
  required ValueChanged<String> onSelectType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdvancedFieldLibraryCards(
        selectedType: 'Formula',
        onSelectType: onSelectType,
      ),
      const SizedBox(height: 14),
      FormulaAdvancedConfig(
        field: f,
        schema: schema,
        fieldOptions: fieldOptions,
        onChanged: (formula) => set('formula', formula),
      ),
    ],
  );
}
