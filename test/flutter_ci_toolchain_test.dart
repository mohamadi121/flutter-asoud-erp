import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Flutter CI jobs use the same explicit SDK release', () {
    final workflow = File('.github/workflows/flutter.yml').readAsStringSync();
    final pin = RegExp(
      r"^  FLUTTER_VERSION: '([0-9]+\.[0-9]+\.[0-9]+)'\r?$",
      multiLine: true,
    ).firstMatch(workflow);
    expect(pin, isNotNull, reason: 'The moving stable channel is not an SDK pin.');

    final setupBlocks = workflow
        .split('uses: subosito/flutter-action@v2')
        .skip(1)
        .map((part) => part.split(RegExp(r'\r?\n      - ')).first);
    expect(setupBlocks, isNotEmpty);
    for (final setup in setupBlocks) {
      expect(setup, contains(r'flutter-version: ${{ env.FLUTTER_VERSION }}'));
    }
    // SDK compatibility must not be achieved by suppressing analyzer failures.
    expect(workflow, contains('run: flutter analyze'));
    expect(workflow, isNot(contains('--no-fatal-infos')));
    expect(workflow, isNot(contains('--no-fatal-warnings')));
  });
}
