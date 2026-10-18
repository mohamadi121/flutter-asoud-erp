import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:asoud_erp/features/form_builder/form_runtime/formula_engine.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/form_formula_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final vector in fixture['cases'] as List<dynamic>) {
    final item = vector as Map<String, dynamic>;
    test('formula vector: ${item['name']}', () {
      final schema = item['schema'];
      if (schema != null) {
        final problems = schemaProblems(schema as Map<String, dynamic>);
        expect(
          problems,
          contains(item['error'] == 'cycle'
              ? 'چرخه وابستگی وجود دارد.'
              : 'فیلد ورودی قانون یا فرمول وجود ندارد.'),
        );
        return;
      }
      final result = calculateForm(
        item['formula'] as Map<String, dynamic>,
        item['values'] as Map<String, dynamic>,
      );
      final errors = <String, String>{
        'divide_by_zero': 'تقسیم بر صفر در فرمول مجاز نیست.',
        'two_inputs': 'این محاسبه به دو ورودی نیاز دارد.',
        'unsupported': 'محاسبه پشتیبانی نمی‌شود.',
      };
      expect(result, item['expected'] ?? errors[item['error']]);
    });
  }
}
