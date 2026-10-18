import 'package:flutter/material.dart';

import '../field_type_grid.dart';

/// The column palette deliberately reuses the locked field cards while
/// excluding repeating tables: nested tables are not supported by the schema.
class ColumnTypeCards extends StatelessWidget {
  const ColumnTypeCards({
    required this.selectedType,
    required this.onSelectType,
    super.key,
  });

  final String selectedType;
  final ValueChanged<String> onSelectType;

  @override
  Widget build(BuildContext context) => FieldTypeGrid(
        selectedType: selectedType,
        allowTable: false,
        onSelectType: onSelectType,
      );
}
