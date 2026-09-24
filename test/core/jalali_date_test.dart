import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts Gregorian dates to Jalali', () {
    expect(
        JalaliDate.fromDateTime(DateTime(2025, 3, 21)).format(), '1404/01/01');
    expect(
        JalaliDate.fromDateTime(DateTime(2024, 3, 20)).format(), '1403/01/01');
    expect(
        JalaliDate.fromDateTime(DateTime(2026, 9, 23)).format(), '1405/07/01');
    expect(
        JalaliDate.fromDateTime(DateTime(2025, 3, 20)).format(), '1403/12/30');
    expect(
        JalaliDate.fromDateTime(DateTime(2000, 1, 1)).format(), '1378/10/11');
  });

  test('formats the long Persian date with weekday and month name', () {
    expect(formatJalaliLong(DateTime(2026, 9, 24)), 'پنجشنبه ۲ مهر ۱۴۰۵');
    expect(formatJalaliLong(DateTime(2026, 9, 12)), 'شنبه ۲۱ شهریور ۱۴۰۵');
  });

  test('converts digits to Persian', () {
    expect(toPersianDigits(1405), '۱۴۰۵');
    expect(toPersianDigits('A-09'), 'A-۰۹');
  });
}
