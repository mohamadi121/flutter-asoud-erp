import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_runtime/schema_migration.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';

void main() {
  final legacy = <String, dynamic>{
    'schema_version': 1,
    'kind': 'Request',
    'title': 'فرم قدیمی',
    'sections': [
      {
        'id': 'main',
        'title': 'اصلی',
        'fields': [
          {'key': 'state', 'label': 'وضعیت', 'type': 'Select', 'options': ['جدید', 'تأیید']},
          {'key': 'tags', 'label': 'برچسب', 'type': 'MultiSelect', 'options': ['الف', 'ب']},
        ],
      },
    ],
    'rules': [
      {
        'target': 'tags',
        'action': 'visible',
        'join': 'and',
        'conditions': [
          {'field': 'state', 'op': 'eq', 'value': 'تأیید'},
        ],
      },
    ],
  };

  test('legacy choices migrate deterministically without changing the source', () {
    final first = migrateFormSchema(legacy);
    final second = migrateFormSchema(legacy);
    final fields = (first['sections'] as List).first['fields'] as List;
    expect(first['schema_version'], formSchemaVersion);
    expect(fields.first['options'], [
      {'id': 'option_0_0_0', 'label': 'جدید'},
      {'id': 'option_0_0_1', 'label': 'تأیید'},
    ]);
    expect(first, second);
    expect((legacy['sections'] as List).first['fields'].first['options'], ['جدید', 'تأیید']);
    expect((first['rules'] as List).first['conditions'].first['value'], 'option_0_0_1');
  });

  test('legacy submitted values migrate to ids and deleted ids have a safe label', () {
    final values = <String, dynamic>{'state': 'تأیید', 'tags': ['الف', 'ب']};
    final migrated = migrateFormSchema(legacy, values: values);
    final fields = (migrated['sections'] as List).first['fields'] as List;
    expect(values, {'state': 'option_0_0_1', 'tags': ['option_0_1_0', 'option_0_1_1']});
    expect(choiceOptionLabel(fields.first as Map<String, dynamic>, 'missing'), deletedChoiceOptionLabel);
  });

  test('renaming a choice keeps its identifier', () {
    final field = <String, dynamic>{
      'options': [
        {'id': 'option_saved', 'label': 'قبلی'},
      ],
    };
    final updated = updateChoiceOptions(field, 'قبلی\nتازه');
    expect(updated.first['id'], 'option_saved');
    expect(updated.last['id'], startsWith('option_'));
  });

  test('schema validation rejects malformed option identifiers', () {
    final schema = migrateFormSchema(legacy);
    final fields = (schema['sections'] as List).first['fields'] as List;
    (fields.first as Map<String, dynamic>)['options'] = [
      {'id': '1bad', 'label': 'نامعتبر'},
    ];
    expect(schemaProblems(schema), contains('وضعیت: گزینه‌های انتخابی معتبر نیستند.'));
  });
}
