import '../form_repository.dart';

const formSchemaVersion = 2;
const deletedChoiceOptionLabel = 'گزینهٔ حذف‌شده';

List<FormMap> choiceOptions(FormMap field) {
  final options = field['options'] as List? ?? [];
  return [
    for (var index = 0; index < options.length; index++)
      if (options[index] is Map)
        formMap(options[index])
      else
        {'id': 'legacy_option_$index', 'label': '${options[index]}'},
  ].where((option) => option['id'] != null && option['label'] != null).toList();
}

String? choiceOptionId(FormMap field, dynamic value) {
  for (final option in choiceOptions(field)) {
    if (option['id'] == value || option['label'] == value) return '${option['id']}';
  }
  return null;
}

String choiceOptionLabel(FormMap field, dynamic id) {
  for (final option in choiceOptions(field)) {
    if (option['id'] == id) return '${option['label']}';
  }
  return deletedChoiceOptionLabel;
}

String newChoiceOptionId() => 'option_${newFormId()}';

List<FormMap> updateChoiceOptions(FormMap field, String text) {
  final retained = <String, String>{
    for (final option in choiceOptions(field)) '${option['label']}': '${option['id']}',
  };
  final seen = <String>{};
  return text
      .split('\n')
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty && seen.add(label))
      .map((label) => {'id': retained[label] ?? newChoiceOptionId(), 'label': label})
      .toList();
}

FormMap migrateFormSchema(FormMap source, {FormMap? values}) {
  final schema = copyForm(source);
  final labelsByField = <String, Map<String, String>>{};

  void migrateFields(List<FormMap> fields, List<int> path, FormMap? currentValues) {
    for (var index = 0; index < fields.length; index++) {
      final field = fields[index];
      final fieldPath = [...path, index];
      if (field['type'] == 'Select' || field['type'] == 'MultiSelect') {
        final oldOptions = field['options'] as List? ?? [];
        final labels = <String, String>{};
        final options = <FormMap>[];
        for (var optionIndex = 0; optionIndex < oldOptions.length; optionIndex++) {
          final old = oldOptions[optionIndex];
          final option = old is Map
              ? formMap(old)
              : <String, dynamic>{'label': '$old'};
          option.putIfAbsent(
            'id',
            () => 'option_${[...fieldPath, optionIndex].join('_')}',
          );
          if (option['id'] != null && option['label'] != null) {
            options.add(option);
            labels['${option['label']}'] = '${option['id']}';
          }
        }
        field['options'] = options;
        labelsByField['${field['key']}'] = labels;
        if (currentValues != null && currentValues.containsKey(field['key'])) {
          final value = currentValues[field['key']];
          currentValues[field['key']] = value is List
              ? value.map((item) => labels['$item'] ?? item).toList()
              : labels['$value'] ?? value;
        }
      }
      if (field['type'] == 'Table') {
        final columns = formMaps(field['columns']);
        field['columns'] = columns;
        final rows = currentValues?[field['key']];
        if (rows is List) {
          for (final row in rows.whereType<Map>()) {
            final migratedRow = formMap(row);
            migrateFields(columns, fieldPath, migratedRow);
            row
              ..clear()
              ..addAll(migratedRow);
          }
        } else {
          migrateFields(columns, fieldPath, null);
        }
      }
    }
  }

  final sections = formMaps(schema['sections']);
  schema['sections'] = sections;
  for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    final fields = formMaps(sections[sectionIndex]['fields']);
    sections[sectionIndex]['fields'] = fields;
    migrateFields(fields, [sectionIndex], values);
  }
  final rules = formMaps(schema['rules']);
  schema['rules'] = rules;
  for (final rule in rules) {
    final conditions = formMaps(rule['conditions']);
    rule['conditions'] = conditions;
    for (final condition in conditions) {
      final optionIds = labelsByField['${condition['field']}'];
      if (optionIds != null) {
        final value = condition['value'];
        condition['value'] = value is List
            ? value.map((item) => optionIds['$item'] ?? item).toList()
            : optionIds['$value'] ?? value;
      }
    }
  }
  schema['schema_version'] = formSchemaVersion;
  return schema;
}

FormMap migrateFormRecord(FormMap record) {
  final migrated = copyForm(record);
  final values = migrated['values'] is Map ? formMap(migrated['values']) : null;
  migrated['schema'] = migrateFormSchema(formMap(migrated['schema']), values: values);
  if (values != null) migrated['values'] = values;
  return migrated;
}
