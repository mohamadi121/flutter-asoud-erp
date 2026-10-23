import '../form_repository.dart';
import '../../../core/utils/jalali_date.dart';
import 'record_links.dart';
import 'rules_engine.dart';
import 'schema_migration.dart';

String calculateForm(FormMap formula, FormMap values) {
  try {
    final result = _calculateFormDecimal(formula, values);
    return result.format(((formula['precision'] as num?)?.toInt() ?? 2).clamp(0, 8));
  } on _FormulaException catch (error) {
    return error.message;
  }
}

_FormDecimal _calculateFormDecimal(FormMap formula, FormMap values) {
  if (formula['expression'] != null && '${formula['expression']}'.trim().isNotEmpty) {
    return _ExpressionParser('${formula['expression']}', values).parse();
  }

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

  if (op == 'count') {
    return _FormDecimal.integer(rows.length);
  } else if ({'sum', 'average', 'sum_product', 'min', 'max'}.contains(op) &&
      (formula['table'] != null || (rows.isNotEmpty && columns.isNotEmpty))) {
    if (numbers.isEmpty) return _FormDecimal.zero;
    if (op == 'min') return numbers.reduce((a, b) => a < b ? a : b);
    if (op == 'max') return numbers.reduce((a, b) => a > b ? a : b);
    final sum = numbers.fold(_FormDecimal.zero, (s, number) => s + number);
    if (op == 'average') return sum / _FormDecimal.integer(numbers.length);
    return sum;
  } else if (op == 'add') {
    return args.fold(_FormDecimal.zero, (sum, number) => sum + number);
  } else if (op == 'min' || op == 'max') {
    if (args.isEmpty) throw const _FormulaException('این محاسبه به ورودی نیاز دارد.');
    return args.reduce((a, b) => op == 'min' ? (a < b ? a : b) : (a > b ? a : b));
  } else if (op == 'round') {
    if (args.isEmpty) throw const _FormulaException('این محاسبه به ورودی نیاز دارد.');
    final digits = args.length > 1
        ? args[1].numerator.toInt()
        : ((formula['digits'] as num?)?.toInt() ?? (formula['precision'] as num?)?.toInt() ?? 0);
    return args[0].round(digits);
  } else if (op == 'if') {
    final cond = _evalCondition(formula['condition'], values);
    final branch = cond ? formula['then'] : formula['else'];
    return _evalBranch(branch, values);
  } else if (op == 'chain' || (formula['ops'] is List && (formula['ops'] as List).isNotEmpty)) {
    if (args.isEmpty) throw const _FormulaException('این محاسبه به ورودی نیاز دارد.');
    final ops = (formula['ops'] as List).map((e) => '$e').toList();
    if (args.length != ops.length + 1) throw const _FormulaException('این محاسبه به دو ورودی نیاز دارد.');

    final remArgs = <_FormDecimal>[args[0]];
    final remOps = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final operation = ops[i];
      final nextVal = args[i + 1];
      if (operation == 'multiply' || operation == 'divide' || operation == 'percent') {
        final prevVal = remArgs.removeLast();
        if (operation == 'multiply') {
          remArgs.add(prevVal * nextVal);
        } else if (operation == 'divide') {
          if (nextVal.isZero) {
            throw const _FormulaException('تقسیم بر صفر در فرمول مجاز نیست.');
          }
          remArgs.add(prevVal / nextVal);
        } else if (operation == 'percent') {
          remArgs.add(prevVal * nextVal / _FormDecimal.integer(100));
        }
      } else if (operation == 'add' || operation == 'subtract') {
        remOps.add(operation);
        remArgs.add(nextVal);
      } else {
        throw const _FormulaException('محاسبه پشتیبانی نمی‌شود.');
      }
    }
    var value = remArgs[0];
    for (var i = 0; i < remOps.length; i++) {
      final operation = remOps[i];
      final nextVal = remArgs[i + 1];
      if (operation == 'add') {
        value = value + nextVal;
      } else if (operation == 'subtract') {
        value = value - nextVal;
      }
    }
    return value;
  } else {
    if (args.length != 2) throw const _FormulaException('این محاسبه به دو ورودی نیاز دارد.');
    return switch (op) {
      'subtract' => args[0] - args[1],
      'multiply' => args[0] * args[1],
      'percent' => args[0] * args[1] / _FormDecimal.integer(100),
      'divide' => args[1].isZero ? throw const _FormulaException('تقسیم بر صفر در فرمول مجاز نیست.') : args[0] / args[1],
      _ => throw const _FormulaException('محاسبه پشتیبانی نمی‌شود.'),
    };
  }
}

bool _evalCondition(dynamic cond, FormMap values) {
  if (cond is String) {
    return !_ExpressionParser(cond, values).parse().isZero;
  }
  if (cond is Map) {
    final op = '${cond['op'] ?? cond['cmp'] ?? 'eq'}';
    _FormDecimal left, right;
    if (cond['inputs'] is List && (cond['inputs'] as List).length >= 2) {
      final inputs = cond['inputs'] as List;
      left = _evalBranch(inputs[0], values);
      right = _evalBranch(inputs[1], values);
    } else {
      left = _evalBranch(cond['left'], values);
      right = _evalBranch(cond['right'], values);
    }
    return switch (op) {
      '>' || 'gt' => left > right,
      '<' || 'lt' => left < right,
      '=' || '==' || 'eq' => left == right,
      '>=' || 'ge' => left >= right,
      '<=' || 'le' => left <= right,
      '!=' || 'ne' => left != right,
      _ => false,
    };
  }
  return false;
}

_FormDecimal _evalBranch(dynamic branch, FormMap values) {
  if (branch is Map) {
    return _calculateFormDecimal(formMap(branch), values);
  }
  if (branch is num) {
    return _FormDecimal.parse(branch);
  }
  if (branch is String) {
    if (values.containsKey(branch)) {
      return _FormDecimal.parse(values[branch]);
    }
    try {
      return _FormDecimal.parse(branch);
    } catch (_) {
      return _FormDecimal.parse(values[branch]);
    }
  }
  return _FormDecimal.zero;
}

class _ExpressionParser {
  _ExpressionParser(String exprStr, this.values)
      : tokens = _tokenize(exprStr);

  final FormMap values;
  final List<String> tokens;
  int pos = 0;

  static List<String> _tokenize(String s) {
    final latin = toLatinDigits(s).replaceAll('٫', '.').replaceAll('٬', '').trim();
    final pattern = RegExp(
        r'([0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|<=|>=|!=|==|[<>=+\-*/%(),«»])');
    final matches = pattern.allMatches(latin);
    final result = <String>[];
    for (final m in matches) {
      final t = m.group(0)!;
      if (t != '«' && t != '»') {
        result.add(t);
      }
    }
    return result;
  }

  String? peek() => pos < tokens.length ? tokens[pos] : null;

  String consume([String? expected]) {
    final tok = peek();
    if (expected != null && tok != expected) {
      throw _FormulaException('فرمول معتبر نیست: انتظار $expected به جای $tok');
    }
    pos++;
    return tok ?? '';
  }

  _FormDecimal parse() => parseExpr(true);

  _FormDecimal parseExpr(bool execute) => parseComparison(execute);

  _FormDecimal parseComparison(bool execute) {
    var left = parseAdditive(execute);
    while (['>', '<', '=', '==', '>=', '<=', '!='].contains(peek())) {
      final op = consume();
      final right = parseAdditive(execute);
      if (execute) {
        final cond = switch (op) {
          '>' => left > right,
          '<' => left < right,
          '=' || '==' => left == right,
          '>=' => left >= right,
          '<=' => left <= right,
          '!=' => left != right,
          _ => false,
        };
        left = cond ? _FormDecimal.one : _FormDecimal.zero;
      }
    }
    return left;
  }

  _FormDecimal parseAdditive(bool execute) {
    var left = parseMultiplicative(execute);
    while (['+', '-'].contains(peek())) {
      final op = consume();
      final right = parseMultiplicative(execute);
      if (execute) {
        left = op == '+' ? left + right : left - right;
      }
    }
    return left;
  }

  _FormDecimal parseMultiplicative(bool execute) {
    var left = parseUnary(execute);
    while (['*', '/', '%'].contains(peek())) {
      final op = consume();
      final right = parseUnary(execute);
      if (execute) {
        if (op == '*') {
          left = left * right;
        } else if (op == '/') {
          if (right.isZero) {
            throw const _FormulaException('تقسیم بر صفر در فرمول مجاز نیست.');
          }
          left = left / right;
        } else if (op == '%') {
          left = (left * right) / _FormDecimal.integer(100);
        }
      }
    }
    return left;
  }

  _FormDecimal parseUnary(bool execute) {
    if (peek() == '-') {
      consume('-');
      final val = parseUnary(execute);
      return execute ? -val : _FormDecimal.zero;
    }
    if (peek() == '+') {
      consume('+');
      return parseUnary(execute);
    }
    return parsePrimary(execute);
  }

  _FormDecimal parsePrimary(bool execute) {
    final tok = peek();
    if (tok == null) {
      throw const _FormulaException('فرمول خالی است.');
    }
    if (tok == '(') {
      consume('(');
      final val = parseExpr(execute);
      consume(')');
      return val;
    }

    if (RegExp(r'^[0-9]').hasMatch(tok)) {
      consume();
      return _FormDecimal.parse(tok);
    }

    final ident = consume();
    if (peek() == '(') {
      consume('(');
      final fn = ident.toUpperCase();
      if (fn == 'IF') {
        final condVal = parseExpr(execute);
        final condBool = execute && !condVal.isZero;
        consume(',');
        final trueVal = parseExpr(execute && condBool);
        consume(',');
        final falseVal = parseExpr(execute && !condBool);
        consume(')');
        return execute ? (condBool ? trueVal : falseVal) : _FormDecimal.zero;
      } else if (fn == 'ROUND') {
        final x = parseExpr(execute);
        var digits = 0;
        if (peek() == ',') {
          consume(',');
          final dVal = parseExpr(execute);
          if (execute) digits = dVal.numerator.toInt();
        }
        consume(')');
        return execute ? x.round(digits) : _FormDecimal.zero;
      } else if (fn == 'MAX' || fn == 'MIN') {
        final args = <_FormDecimal>[parseExpr(execute)];
        while (peek() == ',') {
          consume(',');
          args.add(parseExpr(execute));
        }
        consume(')');
        if (execute) {
          return args.reduce((a, b) => fn == 'MAX' ? (a > b ? a : b) : (a < b ? a : b));
        }
        return _FormDecimal.zero;
      } else {
        throw _FormulaException('تابع ناشناخته: $ident');
      }
    } else {
      if (execute) {
        return _FormDecimal.parse(values[ident]);
      }
      return _FormDecimal.zero;
    }
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
  bool get isNegative => numerator.isNegative;

  int compareTo(_FormDecimal other) =>
      (numerator * other.denominator - other.numerator * denominator)
          .compareTo(BigInt.zero);

  bool operator <(_FormDecimal other) => compareTo(other) < 0;
  bool operator <=(_FormDecimal other) => compareTo(other) <= 0;
  bool operator >(_FormDecimal other) => compareTo(other) > 0;
  bool operator >=(_FormDecimal other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _FormDecimal && compareTo(other) == 0);

  @override
  int get hashCode => Object.hash(numerator, denominator);

  _FormDecimal operator -() => _FormDecimal(-numerator, denominator);

  _FormDecimal round(int digits) {
    if (digits < 0) digits = 0;
    final factor = _ten(digits);
    var scaled = numerator * factor;
    var rounded = scaled ~/ denominator;
    if ((scaled % denominator).abs() * BigInt.two >= denominator.abs()) {
      rounded += scaled.isNegative ? -BigInt.one : BigInt.one;
    }
    return _FormDecimal(rounded, factor)._reduced();
  }

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
    } else if (field['fetch_from'] == null &&
        (formFlag(field, schema, values, 'readonly') || field['type'] == 'Display')) {
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
    if (field['fetch_from'] != null) {
      final parsed = parseFetchFrom(field['fetch_from']);
      final link = fields.where((f) => f['key'] == parsed?.link && f['type'] == 'Link');
      final allowed = link.isEmpty ? null : formFetchAttributes['${link.first['source'] ?? 'Employee'}'];
      if (parsed == null || allowed == null || !allowed.containsKey(parsed.attribute)) {
        problems.add('${field['label']}: مقدار از فیلد معتبر نیست.');
      }
    }
    if ('${field['not_equal'] ?? ''}'.isNotEmpty && !fields.any((f) => f['key'] == field['not_equal'])) {
      problems.add('${field['label']}: فیلد مقایسه حذف شده است.');
    }
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
