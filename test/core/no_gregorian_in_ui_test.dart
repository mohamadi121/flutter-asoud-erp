import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lint: the UI layer must never show Gregorian dates or Latin digit formats.
///
/// Scans `lib/features` for the forbidden patterns that used to leak
/// Gregorian dates and Latin formatting into visible text:
///   - `DateTime.now().toString()`                      raw Gregorian text
///   - `DateFormat(<pattern>)`                          intl date formatting
///   - `.toIso8601String()` used outside the Jalali display helpers or an
///     API payload (historically shown directly inside `Text(...)`)
///
/// API-payload uses of `.toIso8601String()` (map values, `_iso`/`_date`
/// helpers, `.substring(0, 10)` / `.split('T')` trimming and `==`/`!=`
/// comparisons) are allow-listed; anything else fails with file and line.
void main() {
  test('no Gregorian dates or Latin formats leak into the UI layer', () {
    final failures = <String>[];
    final files = _dartFiles(Directory('lib/features'));
    expect(files, isNotEmpty, reason: 'lib/features should exist');

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final where = '${file.path}:${i + 1}';
        if (line.contains('DateTime.now().toString()')) {
          failures.add('$where: DateTime.now().toString()');
        }
        if (line.contains('DateFormat(')) {
          failures.add('$where: DateFormat(');
        }
        if (line.contains('.toIso8601String()') &&
            !_isAllowedIsoUse(lines, i)) {
          failures.add('$where: .toIso8601String() not through a Jalali '
              'helper / API payload: ${line.trim()}');
        }
      }
    }

    expect(failures, isEmpty,
        reason: 'Gregorian/Latin leaks into lib/features:\n'
            '${failures.join('\n')}');
  });
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

bool _isAllowedIsoUse(List<String> lines, int index) {
  final line = lines[index];

  // Display use through a Jalali helper (possibly opened on a previous line).
  if (line.contains('formatJalali')) return true;
  for (var j = index - 1; j >= 0 && j >= index - 3; j--) {
    if (lines[j].contains('formatJalali')) return true;
  }
  // Any `.toIso8601String()` inside / around a `Text(...)` widget must go
  // through a Jalali helper; nothing else may render an ISO timestamp.
  if (_nearWidget(lines, index, 'Text(')) return false;

  // Canonical ISO date trimming on payloads.
  if (line.contains('.toIso8601String().substring(0, 10)')) return true;
  if (line.contains("toIso8601String().split('T').first")) return true;
  // Revision/date comparisons on stored ISO values.
  if (RegExp(r'toIso8601String\(\)\s*(==|!=)').hasMatch(line)) return true;
  // API payload map values: `'key': value.toIso8601String()`.
  if (RegExp(r':\s*[A-Za-z0-9_?.()!]*\.toIso8601String\(\)').hasMatch(line)) {
    return true;
  }
  // Local helpers/assignments: `=> value.toIso8601String()`.
  if (RegExp(r'=\s*[>A-Za-z0-9_?.()\s]*\.toIso8601String\(\)').hasMatch(line)) {
    return true;
  }
  // Log/queue identifiers built from a timestamp string.
  if (line.contains('toIso8601String()}|')) return true;
  return false;
}

bool _nearWidget(List<String> lines, int index, String marker) {
  final lo = (index - 3) < 0 ? 0 : index - 3;
  final hi = (index + 3) < lines.length ? index + 3 : lines.length - 1;
  for (var j = lo; j <= hi; j++) {
    if (lines[j].contains(marker)) return true;
  }
  return false;
}
