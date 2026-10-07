import 'package:asoud_erp/features/workflows/domain/entities/workflow_definition.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

void main() {
  test('the contract field lists round-trip every §3 attribute', () {
    for (final entry in templateFieldFixtures().entries) {
      for (final raw in entry.value) {
        final map = WorkflowFormFieldDefinition.fromMap(raw).toMap();
        // `required` and `options` are always written; everything else the
        // contract defines must come back unchanged.
        for (final key in raw.keys) {
          expect(map[key], raw[key], reason: '${entry.key}.${raw['key']}.$key');
        }
        for (final key in map.keys) {
          expect(raw.containsKey(key) || key == 'required' || key == 'options',
              isTrue,
              reason: '${entry.key}.${raw['key']} gained $key');
        }
        expect(WorkflowFormFieldDefinition.fromMap(map),
            WorkflowFormFieldDefinition.fromMap(raw));
      }
    }
  });

  test('new attributes are parsed', () {
    final fields = {
      for (final field in templateFieldFixtures()['leave']!)
        field['key'] as String: WorkflowFormFieldDefinition.fromMap(field)
    };
    final kind = fields['request_kind']!;
    expect(kind.widget, 'segmented');
    expect(kind.optionLabels, {'Daily': 'روزانه', 'Hourly': 'ساعتی'});
    expect(kind.optionLabel('Hourly'), 'ساعتی');
    expect(kind.optionLabel('Other'), 'Other');

    final start = fields['start_date']!;
    expect(start.visibleWhen!.field, 'request_kind');
    expect(start.visibleWhen!.equals, 'Daily');
    expect(start.visibleWhen!.matches('Daily'), isTrue);
    expect(start.visibleWhen!.matches('Hourly'), isFalse);
    expect(fields['start_time']!.type, 'Time');
    expect(fields['duration']!.auto, 'leave_duration');
    expect(fields['leave_type']!.source, 'leave_type');
    expect(fields['location']!.defaultSource, 'employee_branch');
    expect(fields['reason']!.maxLength, 2000);
    expect(fields['requester']!.editable, isFalse);
    expect(fields['reason']!.editable, isTrue);

    final purchase = {
      for (final field in templateFieldFixtures()['purchase']!)
        field['key'] as String: WorkflowFormFieldDefinition.fromMap(field)
    };
    expect(purchase['needed_date']!.minDate, 'today');
    expect(purchase['cost_center']!.requiredBySetting,
        'request_cost_center_required');
    final rows = purchase['items']!.rowOptions!;
    expect(rows.itemScope, 'purchase');
    expect(rows.note, isTrue);
    expect(rows.attachment, isTrue);
    expect(rows.minRows, 1);
    expect(rows.maxRows, 100);
  });

  test('visible_when accepts a list of values', () {
    final field = WorkflowFormFieldDefinition.fromMap({
      'key': 'x',
      'label': 'x',
      'type': 'Short Text',
      'visible_when': {
        'field': 'kind',
        'in': ['A', 'B']
      },
    });
    expect(field.visibleWhen!.inList, ['A', 'B']);
    expect(field.visibleWhen!.matches('B'), isTrue);
    expect(field.visibleWhen!.matches('C'), isFalse);
    expect(field.toMap()['visible_when'], {
      'field': 'kind',
      'in': ['A', 'B']
    });
  });

  test('resolved defaults of request_options are kept', () {
    final purchase = requestOptionFixtures().first['fields'] as List;
    final requester = WorkflowFormFieldDefinition.fromMap(
        purchase.firstWhere((f) => (f as Map)['key'] == 'requester') as Map);
    expect(requester.defaultValue, 'sara@x');
    expect(requester.defaultLabel, 'سارا محمدی');
    expect(requester.toMap()['default_label'], 'سارا محمدی');
  });

  test('older definitions without the new attributes are unchanged', () {
    final field = WorkflowFormFieldDefinition.fromMap(
        {'key': 'a', 'label': 'A', 'type': 'Short Text'});
    expect(field.toMap(), {
      'key': 'a',
      'label': 'A',
      'type': 'Short Text',
      'required': false,
      'options': <String>[],
    });
    expect(field.editable, isTrue);
    expect(field.rowOptions, isNull);
    expect(field.visibleWhen, isNull);
  });
}
