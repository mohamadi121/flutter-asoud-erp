import '../form_repository.dart';
import '../../../core/utils/jalali_date.dart';
import 'rules_engine.dart';
import 'schema_migration.dart';

String calculateForm(FormMap formula, FormMap values) {
  try {
    final args = (formula['inputs'] as List? ?? [])
        .map((key) => _FormDecimal.parse(values[key]))
        .toList();
    final rows = formMaps(values[formula['table']]);
    final columns = formula['columns'] as List? ?? [];
    final numbers = rows.map((row) => columns.isEmpty
        ? _FormDecimal.zero
        : _FormDecimal.parse(row[columns.first]) *
            (formula['op'] == 'sum_product' && columns.length > 1
                ? _FormDecimal.parse(row[columns[1]])
                : _FormDecimal.one)).toList();
    final op = '${formula['op']}';
    _FormDecimal result;
    if (op == 'count') {
      result = _FormDecimal.integer(rows.length);
    } else if ({'sum', 'average', 'sum_product'}.contains(op)) {
      result = numbers.fold(_FormDecimal.zero, (sum, number) => sum + number);
      if (op == 'average' && numbers.isNotEmpty) result = result / _FormDecimal.integer(numbers.length);
    } else if (op == 'add') {
      result = args.fold(_FormDecimal.zero, (sum, number) => sum + number);
    } else if (op == 'chain' || (formula['ops'] is List && (formula['ops'] as List).isNotEmpty)) {
      if (args.isEmpty) return 'این محاسبه به ورودی نیاز دارد.';
      final ops = (formula['ops'] as List).map((e) => '$e').toList();
      if (args.length != ops.length + 1) return 'این محاسبه به دو ورودی نیاز دارد.';
      result = args[0];
      for (var i = 0; i < ops.length; i++) {
        final next = args[i + 1];
        result = switch (ops[i]) {
          'add' => result + next,
          'subtract' => result - next,
          'multiply' => result * next,
          'divide' => next.isZero ? throw const _FormulaException('تقسیم بر صفر در فرمول مجاز نیست.') : result / next,
          'percent' => result * next / _FormDecimal.integer(100),
          _ => throw const _FormulaException('محاسبه پشتیبانی نمی‌شود.'),
        };
      }
    } else {
      if (args.length != 2) return 'این محاسبه به دو ورودی نیاز دارد.';
      result = switch (op) {
        'subtract' => args[0] - args[1],
        'multiply' => args[0] * args[1],
        'percent' => args[0] * args[1] / _FormDecimal.integer(100),
        'divide' => args[1].isZero ? throw const _FormulaException('تقسیم بر صفر در فرمول مجاز نیست.') : args[0] / args[1],
        _ => throw const _FormulaException('محاسبه پشتیبانی نمی‌شود.'),
      };
    }
    return result.format(((formula['precision'] as num?)?.toInt() ?? 2).clamp(0, 8));
  } on _FormulaException catch (error) {
    return error.message;
  }
}

class _FormulaException implements Exception {
  const _FormulaException(this.message);
  final String message;
}

class _FormDecimal {
  const _FormDecimal(this.numerator, this.denominator);

  factory _FormDecimal.integer(int value) => _FormDecimal(BigInt.from(value), BigInt.one);
  factory _FormDecimal.parse(dynamic value) {
    final source = toLatinDigits('${value ?? ''}').replaceAll('٫', '.').trim();
    if (source.isEmpty) return zero;
    final match = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$').firstMatch(source);
    if (match == null || (match.group(2)!.isEmpty && (match.group(3) ?? '').isEmpty)) {
      throw const _FormulaException('مقدار عددی معتبر نیست.');
    }
    final negative = match.group(1) == '-';
    var digits = '${match.group(2)}${match.group(3) ?? ''}';
    var scale = (match.group(3) ?? '').length - int.parse(match.group(4) ?? '0');
    var numerator = BigInt.parse(digits.isEmpty ? '0' : digits);
    if (negative) numerator = -numerator;
    if (scale < 0) {
      numerator *= _ten(-scale);
      scale = 0;
    }
    return _FormDecimal(numerator, _ten(scale))._reduced();
  }

  final BigInt numerator, denominator;
  static final zero = _FormDecimal(BigInt.zero, BigInt.one);
  static final one = _FormDecimal(BigInt.one, BigInt.one);

  bool get isZero => numerator == BigInt.zero;
  _FormDecimal operator +(_FormDecimal other) => _FormDecimal(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      )._reduced();
  _FormDecimal operator -(_FormDecimal other) => _FormDecimal(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      )._reduced();
  _FormDecimal operator *(_FormDecimal other) =>
      _FormDecimal(numerator * other.numerator, denominator * other.denominator)._reduced();
  _FormDecimal operator /(_FormDecimal other) =>
      _FormDecimal(numerator * other.denominator, denominator * other.numerator)._reduced();

  _FormDecimal _reduced() {
    final gcd = numerator.abs().gcd(denominator.abs());
    return _FormDecimal(numerator ~/ gcd, denominator ~/ gcd);
  }

  String format(int precision) {
    final factor = _ten(precision);
    var scaled = numerator * factor;
    var rounded = scaled ~/ denominator;
    if ((scaled % denominator).abs() * BigInt.two >= denominator.abs()) {
      rounded += scaled.isNegative ? -BigInt.one : BigInt.one;
    }
    final sign = rounded.isNegative ? '-' : '';
    final digits = rounded.abs().toString().padLeft(precision + 1, '0');
    return precision == 0
        ? '$sign$digits'
        : '$sign${digits.substring(0, digits.length - precision)}.${digits.substring(digits.length - precision)}';
  }
}

BigInt _ten(int power) => BigInt.from(10).pow(power);

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
  if (schema['schema_version'] != null && schema['schema_version'] != formSchemaVersion) {
    problems.add('نسخه ساختار فرم معتبر نیست.');
  }
  if ('${schema['title'] ?? ''}'.trim().isEmpty) problems.add('عنوان فرم را وارد کنید.');
  final fields = schemaFields(schema), keys = <String>{};
  if (fields.isEmpty) problems.add('حداقل یک فیلد لازم است.');
  for (final field in fields) {
    if (!keys.add('${field['key']}')) problems.add('شناسه فیلد تکراری است.');
    if ('${field['label'] ?? ''}'.trim().isEmpty) problems.add('عنوان یک فیلد خالی است.');
    if (field['type'] == 'Select' || field['type'] == 'MultiSelect') {
      final options = field['options'];
      final ids = <String>{};
      if (options is! List || options.isEmpty || options.length > 100) {
        problems.add('${field['label']}: گزینه‌های انتخابی معتبر نیستند.');
      } else {
        for (final option in options) {
          final choice = option is Map ? formMap(option) : {};
          if (!RegExp(r'^[a-z][a-z0-9_]{0,59}$').hasMatch('${choice['id'] ?? ''}') ||
              '${choice['label'] ?? ''}'.trim().isEmpty ||
              !ids.add('${choice['id']}')) {
            problems.add('${field['label']}: گزینه‌های انتخابی معتبر نیستند.');
            break;
          }
        }
      }
    }
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
