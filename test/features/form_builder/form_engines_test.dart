import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';
import 'package:asoud_erp/features/form_builder/form_runtime/rules_engine.dart';

void main() {
  group('formula engine', () {
    test('calculates scalar and table formulas', () {
      expect(calculateForm({'op': 'add', 'inputs': ['a', 'b']}, {'a': 2, 'b': 3}), '5.00');
      expect(calculateForm({'op': 'subtract', 'inputs': ['a', 'b']}, {'a': 2, 'b': 3}), '-1.00');
      expect(calculateForm({'op': 'multiply', 'inputs': ['a', 'b']}, {'a': 2, 'b': 3}), '6.00');
      expect(calculateForm({'op': 'percent', 'inputs': ['a', 'b']}, {'a': 20, 'b': 5}), '1.00');
      expect(calculateForm({'op': 'divide', 'inputs': ['a', 'b']}, {'a': 5, 'b': 0}), 'تقسیم بر صفر یا فرمول نامعتبر');
      expect(calculateForm({'op': 'sum', 'table': 'rows', 'columns': ['amount']}, {'rows': [{'amount': 2}, {'amount': 3}]}), '5.00');
      expect(calculateForm({'op': 'average', 'table': 'rows', 'columns': ['amount']}, {'rows': []}), '0.00');
      expect(calculateForm({'op': 'count', 'table': 'rows'}, {'rows': [{}, {}]}), '2.00');
    });

    test('orders dependencies and reports cycles', () {
      final schema = {
        'title': 't',
        'sections': [{'fields': [
          {'key': 'a', 'label': 'a', 'type': 'Integer'},
          {'key': 'b', 'label': 'b', 'type': 'Formula', 'formula': {'op': 'add', 'inputs': ['a']}},
          {'key': 'c', 'label': 'c', 'type': 'Formula', 'formula': {'op': 'add', 'inputs': ['b']}},
        ]}],
        'rules': [],
      };
      expect(evaluatedValues(schema, {'a': 4})['c'], '4.00');
      expect(schemaProblems({...schema, 'sections': [{'fields': [
        {'key': 'a', 'label': 'a', 'type': 'Formula', 'formula': {'inputs': ['b']}},
        {'key': 'b', 'label': 'b', 'type': 'Formula', 'formula': {'inputs': ['a']}},
      ]}]}), contains('چرخه وابستگی وجود دارد.'));
    });
  });

  group('rules engine', () {
    test('evaluates supported conditions', () {
      expect(formCondition({'field': 'a', 'op': 'eq', 'value': '2'}, {'a': 2}, 'Integer'), isTrue);
      expect(formCondition({'field': 'a', 'op': 'ne', 'value': 'x'}, {'a': 'X'}), isFalse);
      expect(formCondition({'field': 'a', 'op': 'gt', 'value': 2}, {'a': 3}), isTrue);
      expect(formCondition({'field': 'a', 'op': 'le', 'value': 3}, {'a': 3}), isTrue);
      expect(formCondition({'field': 'a', 'op': 'empty'}, {'a': []}), isTrue);
      expect(formCondition({'field': 'a', 'op': 'not_empty'}, {'a': 'x'}), isTrue);
      expect(formCondition({'field': 'a', 'op': 'contains', 'value': 'x'}, {'a': ['x']}), isTrue);
      expect(formCondition({'field': 'a', 'op': 'contains', 'value': 'x'}, {'a': 'abc'}), isFalse);
    });

    test('combines visibility and required rules', () {
      final schema = {
        'sections': [{'fields': [
          {'key': 'source', 'label': 's', 'type': 'Text'},
          {'key': 'target', 'label': 't', 'type': 'Text'},
        ]}],
        'rules': [
          {'target': 'target', 'action': 'visible', 'join': 'and', 'conditions': [{'field': 'source', 'op': 'eq', 'value': 'yes'}]},
          {'target': 'target', 'action': 'required', 'join': 'or', 'conditions': [{'field': 'source', 'op': 'eq', 'value': 'yes'}]},
        ],
      };
      final target = schemaFields(schema)[1];
      expect(formFlag(target, schema, {'source': 'yes'}, 'visible'), isTrue);
      expect(formFlag(target, schema, {'source': 'no'}, 'visible'), isFalse);
      expect(formFlag(target, schema, {'source': 'yes'}, 'required'), isTrue);
      expect(formFlag(target, schema, {'source': 'no'}, 'required'), isFalse);
    });
  });
}
