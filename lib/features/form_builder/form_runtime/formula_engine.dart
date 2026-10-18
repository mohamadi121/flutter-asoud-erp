import '../form_repository.dart';
import 'rules_engine.dart';

String calculateForm(FormMap formula, FormMap values) {
  final args = (formula['inputs'] as List? ?? []).map((key) => formNumber(values[key])).toList();
  final rows = formMaps(values[formula['table']]);
  final columns = formula['columns'] as List? ?? [];
  final numbers = rows.map((row) => columns.isEmpty ? 0.0 : formNumber(row[columns.first]) *
      (formula['op'] == 'sum_product' && columns.length > 1 ? formNumber(row[columns[1]]) : 1)).toList();
  double result;
  switch (formula['op']) {
    case 'count': result = rows.length.toDouble();
    case 'sum':
    case 'sum_product': result = numbers.fold(0.0, (a, b) => a + b);
    case 'average': result = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a + b) / numbers.length;
    case 'add': result = args.fold(0.0, (a, b) => a + b);
    default:
      if (args.length != 2) return 'دو ورودی لازم است';
      result = switch (formula['op']) {
        'subtract' => args[0] - args[1], 'multiply' => args[0] * args[1],
        'percent' => args[0] * args[1] / 100, 'divide' => args[1] == 0 ? double.nan : args[0] / args[1], _ => double.nan,
      };
  }
  return result.isFinite ? result.toStringAsFixed(((formula['precision'] as num?)?.toInt() ?? 2).clamp(0, 8)) : 'تقسیم بر صفر یا فرمول نامعتبر';
}

FormMap evaluatedValues(FormMap schema, FormMap raw) {
  final values = {...raw};
  final fields = schemaFields(schema), byKey = {for (final field in fields) field['key']: field};
  final done = <String>{}, visiting = <String>{};
  void evaluate(FormMap field) {
    final key = '${field['key']}';
    if (done.contains(key) || !visiting.add(key)) return;
    for (final rule in formMaps(schema['rules']).where((rule) => rule['target'] == key && rule['enabled'] != false)) {
      for (final condition in formMaps(rule['conditions'])) {
        if (byKey[condition['field']] != null) evaluate(byKey[condition['field']]!);
      }
    }
    final formula = formMap(field['formula']);
    for (final dependency in [...(formula['inputs'] as List? ?? []), if (formula['table'] != null) formula['table']]) {
      if (byKey[dependency] != null) evaluate(byKey[dependency]!);
    }
    values.putIfAbsent(key, () => field['default']);
    if (!formFlag(field, schema, values, 'visible')) {
      values.remove(key);
    } else if (field['type'] == 'Table') {
      values[key] = formMaps(values[key]).map((row) => evaluatedValues({'sections': [{'fields': field['columns']}], 'rules': []}, row)).toList();
    } else if (field['type'] == 'Formula') {
      values[key] = calculateForm(formula, values);
    } else if (formFlag(field, schema, values, 'readonly') || field['type'] == 'Display') {
      values[key] = field['default'];
    }
    visiting.remove(key); done.add(key);
  }
  for (final field in fields) { evaluate(field); }
  return values;
}

List<String> schemaProblems(FormMap schema) {
  final problems = <String>[];
  if ('${schema['title'] ?? ''}'.trim().isEmpty) problems.add('عنوان فرم را وارد کنید.');
  final fields = schemaFields(schema), keys = <String>{};
  if (fields.isEmpty) problems.add('حداقل یک فیلد لازم است.');
  for (final field in fields) {
    if (!keys.add('${field['key']}')) problems.add('شناسه فیلد تکراری است.');
    if ('${field['label'] ?? ''}'.trim().isEmpty) problems.add('عنوان یک فیلد خالی است.');
    if (field['type'] == 'Table' && formMaps(field['columns']).isEmpty) problems.add('${field['label']}: ستون جدول را اضافه کنید.');
  }
  final graph = {for (final key in keys) key: <String>{}};
  for (final field in fields) {
    final formula = formMap(field['formula']);
    for (final dependency in [...(formula['inputs'] as List? ?? []), if (formula['table'] != null) formula['table']]) { graph['${field['key']}']!.add('$dependency'); }
  }
  for (final rule in formMaps(schema['rules'])) {
    if (!keys.contains(rule['target'])) { problems.add('فیلد مقصد قانون حذف شده است.'); continue; }
    for (final condition in formMaps(rule['conditions'])) { graph[rule['target']]!.add('${condition['field']}'); }
  }
  final done = <String>{}, visiting = <String>{};
  void visit(String key) {
    if (done.contains(key)) return;
    if (!visiting.add(key)) { problems.add('چرخه وابستگی وجود دارد.'); return; }
    for (final dependency in graph[key] ?? <String>{}) {
      if (!keys.contains(dependency)) {
        problems.add('فیلد ورودی قانون یا فرمول وجود ندارد.');
      } else {
        visit(dependency);
      }
    }
    visiting.remove(key); done.add(key);
  }
  for (final key in keys) { visit(key); }
  return problems.toSet().toList();
}
