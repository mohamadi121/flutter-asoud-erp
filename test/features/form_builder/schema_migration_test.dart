import 'dart:convert';
import 'dart:io';

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

  test('form_schema_legacy_v1 fixture migrates to form_schema_legacy_v2 identically', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final v2Expected = jsonDecode(File('test/fixtures/form_schema_legacy_v2.json').readAsStringSync()) as Map<String, dynamic>;

    final v2Actual = migrateFormSchema(v1);

    expect(v2Actual, equals(v2Expected));
    expect(v2Actual['schema_version'], 2);
    expect(v1['sections'][0]['fields'][0]['options'], ['مرخصی', 'ماموریت']);
    expect(
      (v2Actual['sections'] as List)[0]['fields'][0]['options'],
      [
        {'id': 'option_0_0_0', 'label': 'مرخصی'},
        {'id': 'option_0_0_1', 'label': 'ماموریت'},
      ],
    );
    expect(
      (v2Actual['sections'] as List)[0]['fields'][1]['options'],
      [
        {'id': 'option_0_1_0', 'label': 'پیامک'},
        {'id': 'option_0_1_1', 'label': 'ایمیل'},
      ],
    );
    expect(
      (v2Actual['sections'] as List)[0]['fields'][2]['columns'][0]['options'],
      [
        {'id': 'option_0_2_0_0', 'label': 'اقامت'},
        {'id': 'option_0_2_0_1', 'label': 'ایاب و ذهاب'},
      ],
    );
    expect(
      (v2Actual['rules'] as List)[0]['conditions'][0]['value'],
      'option_0_0_1',
    );
  });

  test('migrating legacy submitted values maps scalar, multiselect, and table column choices', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final values = <String, dynamic>{
      'request_type': 'ماموریت',
      'channels': ['پیامک', 'ایمیل'],
      'expenses': [
        {'expense_type': 'اقامت'},
        {'expense_type': 'ایاب و ذهاب'},
      ],
    };

    final migratedSchema = migrateFormSchema(v1, values: values);
    expect(migratedSchema['schema_version'], 2);
    expect(values['request_type'], 'option_0_0_1');
    expect(values['channels'], ['option_0_1_0', 'option_0_1_1']);
    final expenses = values['expenses'] as List;
    expect(expenses[0]['expense_type'], 'option_0_2_0_0');
    expect(expenses[1]['expense_type'], 'option_0_2_0_1');
    expect((migratedSchema['rules'] as List)[0]['conditions'][0]['value'], 'option_0_0_1');
  });

  test('migrateFormRecord migrates both schema and values without mutating source record', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final record = <String, dynamic>{
      'name': 'ENTRY-00001',
      'schema': v1,
      'values': {'request_type': 'مرخصی'},
    };

    final migratedRecord = migrateFormRecord(record);
    expect(migratedRecord['schema']['schema_version'], 2);
    expect(migratedRecord['values']['request_type'], 'option_0_0_0');
    expect(record['schema']['schema_version'], 1);
    expect(record['values']['request_type'], 'مرخصی');
  });

  test('migrating an already-v2 schema is a no-op (idempotent)', () {
    final v2Expected = jsonDecode(File('test/fixtures/form_schema_legacy_v2.json').readAsStringSync()) as Map<String, dynamic>;
    final v2Migrated = migrateFormSchema(v2Expected);
    expect(v2Migrated, equals(v2Expected));
  });

  test('loading the same v1 twice yields identical ids', () {
    final v1First = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final v1Second = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;

    final first = migrateFormSchema(v1First);
    final second = migrateFormSchema(v1Second);

    expect(first, equals(second));
  });

  test('regression: migrating table rows with strongly typed maps does not throw type error', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final values = <String, dynamic>{
      'expenses': <Map<String, String>>[
        <String, String>{'expense_type': 'اقامت'},
      ],
    };

    final migrated = migrateFormSchema(v1, values: values);
    expect(migrated['schema_version'], 2);
    final expenses = values['expenses'] as List;
    expect(expenses.first['expense_type'], 'option_0_2_0_0');
  });

  test('regression: empty table rows list still migrates column options to v2 format', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    final values = <String, dynamic>{
      'expenses': <dynamic>[],
    };

    final migrated = migrateFormSchema(v1, values: values);
    expect(migrated['schema_version'], 2);
    final tableCol = (migrated['sections'] as List)[0]['fields'][2]['columns'][0];
    expect(tableCol['options'], [
      {'id': 'option_0_2_0_0', 'label': 'اقامت'},
      {'id': 'option_0_2_0_1', 'label': 'ایاب و ذهاب'},
    ]);
  });

  test('regression: rule conditions with list values or null values map accurately', () {
    final v1 = jsonDecode(File('test/fixtures/form_schema_legacy_v1.json').readAsStringSync()) as Map<String, dynamic>;
    (v1['rules'] as List).add({
      'target': 'expenses',
      'action': 'visible',
      'join': 'and',
      'conditions': [
        {'field': 'channels', 'op': 'in', 'value': ['پیامک', 'ایمیل']},
        {'field': 'request_type', 'op': 'is_empty', 'value': null},
      ],
    });

    final migrated = migrateFormSchema(v1);
    final secondRule = (migrated['rules'] as List)[1];
    final conditions = secondRule['conditions'] as List;
    expect(conditions[0]['value'], ['option_0_1_0', 'option_0_1_1']);
    expect(conditions[1]['value'], isNull);
  });
}
