import '../form_repository.dart';
import '../../../core/utils/jalali_date.dart';

List<FormMap> schemaFields(FormMap schema) =>
    formMaps(schema['sections']).expand((s) => formMaps(s['fields'])).toList();

bool isEmptyValue(dynamic value) =>
    value == null || value == '' || (value is List && value.isEmpty);

double formNumber(dynamic value) => double.tryParse(toLatinDigits('$value')) ?? 0;

bool formCondition(FormMap condition, FormMap values, [String? type]) {
  final actual = values[condition['field']], expected = condition['value'];
  final actualNumber = double.tryParse(toLatinDigits('$actual'));
  final expectedNumber = double.tryParse(toLatinDigits('$expected'));
  final comparison = actualNumber != null && expectedNumber != null
      ? actualNumber.compareTo(expectedNumber)
      : '${actual ?? ''}'.compareTo('${expected ?? ''}');
  return switch (condition['op']) {
    'eq' => ['Integer', 'Decimal', 'Money', 'Rating', 'Formula'].contains(type)
        ? actualNumber == expectedNumber
        : '$actual'.toLowerCase() == '$expected'.toLowerCase(),
    'ne' => ['Integer', 'Decimal', 'Money', 'Rating', 'Formula'].contains(type)
        ? actualNumber != expectedNumber
        : '$actual'.toLowerCase() != '$expected'.toLowerCase(),
    'gt' => comparison > 0,
    'lt' => comparison < 0,
    'ge' => comparison >= 0,
    'le' => comparison <= 0,
    'empty' => isEmptyValue(actual),
    'not_empty' => !isEmptyValue(actual),
    'contains' => actual is List
        ? actual.contains(expected)
        : '${actual ?? ''}'.contains('$expected'),
    _ => false,
  };
}

bool formFlag(FormMap field, FormMap schema, FormMap values, String action) {
  final rules = formMaps(schema['rules'])
      .where((rule) =>
          rule['target'] == field['key'] &&
          rule['action'] == action &&
          rule['enabled'] != false)
      .toList();
  final base = action == 'visible' || field[action] == true;
  if (rules.isEmpty) return base;
  final triggered = rules.any((rule) {
    final matches = formMaps(rule['conditions']).map((condition) => formCondition(
          condition,
          values,
          schemaFields(schema)
              .where((field) => field['key'] == condition['field'])
              .firstOrNull?['type'] as String?,
        ));
    return rule['join'] == 'and' ? matches.every((match) => match) : matches.any((match) => match);
  });
  return action == 'visible' ? triggered : base || triggered;
}
