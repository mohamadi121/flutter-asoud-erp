import 'package:asoud_erp/core/utils/file_name_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fileNameLabel', () {
    test('a plain name is returned as-is', () {
      expect(fileNameLabel('report.pdf'), 'report.pdf');
    });

    test('a forward-slash path shows only the final segment', () {
      expect(fileNameLabel('/private/files/2026/11/28/report.pdf'),
          'report.pdf');
    });

    test('a query string is stripped (the token never appears)', () {
      expect(fileNameLabel('/private/files/report.pdf?token=abc'), 'report.pdf');
    });

    test('a fragment is stripped', () {
      expect(fileNameLabel('/private/files/report.pdf#page=2'), 'report.pdf');
    });

    test('a query string on a bare name is stripped', () {
      expect(fileNameLabel('report.pdf?token=abc'), 'report.pdf');
    });

    test('a percent-encoded Persian name is decoded', () {
      expect(fileNameLabel('/private/files/%D8%B1%D8%A7%D9%87%20%D8%A7%D9%85%D8%A7.pdf'),
          'راه اما.pdf');
    });

    test('a backslash path shows the final segment', () {
      expect(fileNameLabel(r'C:\files\report.pdf'), 'report.pdf');
    });

    test('a trailing slash is handled', () {
      expect(fileNameLabel('/private/files/report.pdf/'), 'report.pdf');
    });

    test('a trailing backslash is handled', () {
      expect(fileNameLabel(r'C:\files\report.pdf\'), 'report.pdf');
    });

    test('a local preview label without a path is shown as-is', () {
      expect(fileNameLabel('پیش‌نمایش محلی: قرارداد.pdf'),
          'پیش‌نمایش محلی: قرارداد.pdf');
    });

    test('a literal percent that is not valid encoding is not mangled', () {
      expect(fileNameLabel('100% done.pdf'), '100% done.pdf');
    });

    test('an empty value is empty', () {
      expect(fileNameLabel(''), '');
      expect(fileNameLabel('   '), '');
    });
  });

  group('fileNamesLabel', () {
    test('a single value is shown', () {
      expect(fileNamesLabel('/private/files/report.pdf'), 'report.pdf');
    });

    test('a list of values is joined with «، »', () {
      expect(fileNamesLabel(['/private/files/a/اول.pdf', '/private/files/b/دوم.xlsx']),
          'اول.pdf، دوم.xlsx');
    });

    test('null and empty are empty', () {
      expect(fileNamesLabel(null), '');
      expect(fileNamesLabel(''), '');
    });
  });
}
