import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Paths (relative to the app root) whose long explanatory single-line titles
/// are accepted on purpose. Empty today: no explanatory string longer than 60
/// characters is clipped with `maxLines: 1` + `TextOverflow.ellipsis`.
const allowList = <String>{};

/// Scans Dart [source] and returns `path:line` for every `Text(...)` that both
/// clips to a single line (`maxLines: 1`) and ellipsizes, while its literal
/// content is explanatory (longer than 60 chars and containing «،» or «.»).
List<String> scanDartSource(String path, String source) {
  final hits = <String>[];
  final call = RegExp(r'(?<![\w.])Text\s*\(');
  for (final match in call.allMatches(source)) {
    final open = source.indexOf('(', match.start);
    final close = _matchingParen(source, open);
    if (close < 0) continue;
    final body = source.substring(open + 1, close);
    if (!RegExp(r'maxLines:\s*1\b').hasMatch(body)) continue;
    if (!body.contains('TextOverflow.ellipsis')) continue;
    if (_explanatoryLiteral(body) == null) continue;
    final line =
        '\n'.allMatches(source.substring(0, match.start)).length + 1;
    hits.add('$path:$line');
  }
  return hits;
}

String? _explanatoryLiteral(String body) {
  final literals = _stringLiterals(body);
  for (final literal in literals) {
    if (_isExplanatory(literal)) return literal;
  }
  if (_isExplanatory(literals.join())) return literals.join();
  return null;
}

bool _isExplanatory(String value) =>
    value.length > 60 && (value.contains('،') || value.contains('.'));

List<String> _stringLiterals(String body) => RegExp(
        "'''[\\s\\S]*?'''|\\\"\\\"\\\"[\\s\\S]*?\\\"\\\"\\\""
        "|'(?:\\\\.|[^'\\\\])*'|\"(?:\\\\.|[^\"\\\\])*\"")
    .allMatches(body)
    .map((m) => m.group(0)!.substring(1, m.group(0)!.length - 1))
    .toList(growable: false);

int _matchingParen(String source, int open) {
  var depth = 0;
  String? quote;
  var i = open;
  while (i < source.length) {
    final char = source[i];
    if (quote != null) {
      if (char == r'\') {
        i += 2;
        continue;
      }
      if (char == quote) quote = null;
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

void main() {
  test('scanner flags a long explanatory Text clipped to one ellipsized line',
      () {
    const violation = """
      Text(
        'قالب و فایل اکسل قبل از ذخیره پیش‌نمایش دارند. جایگاه‌ها می‌توانند خالی باشند و این توضیح بلند است.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      )
    """;
    expect(scanDartSource('sample.dart', violation), ['sample.dart:1']);

    const short = "Text('مدیرعامل', maxLines: 1, overflow: TextOverflow.ellipsis)";
    expect(scanDartSource('sample.dart', short), isEmpty);

    const wraps = "Text('قالب و فایل اکسل قبل از ذخیره پیش‌نمایش دارند و این جمله بسیار طولانی توضیحی است.', softWrap: true)";
    expect(scanDartSource('sample.dart', wraps), isEmpty);
  });

  test('no long explanatory Text in lib/features is clipped with maxLines: 1',
      () {
    final root = Directory('lib/features');
    expect(root.existsSync(), isTrue, reason: 'run the test from the app root');

    final violations = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final hit in scanDartSource(entity.path, entity.readAsStringSync())) {
        if (!allowList.any(hit.startsWith)) violations.add(hit);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Long explanatory text must wrap, not be cut with '
          'maxLines: 1 + TextOverflow.ellipsis. Fix the Text or add the '
          'legitimate single-line list-row title to `allowList`:\n'
          '${violations.join('\n')}',
    );
  });
}
