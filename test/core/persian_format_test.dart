import 'package:asoud_erp/core/utils/persian_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNumber', () {
    test('formats integers with Persian digits and thousands separator', () {
      expect(formatNumber(12450000), '۱۲٬۴۵۰٬۰۰۰');
      expect(formatNumber(8200000), '۸٬۲۰۰٬۰۰۰');
      expect(formatNumber(456700000), '۴۵۶٬۷۰۰٬۰۰۰');
      expect(formatNumber(1000), '۱٬۰۰۰');
      expect(formatNumber(123), '۱۲۳');
      expect(formatNumber(0), '۰');
      expect(formatNumber(-1500), '-۱٬۵۰۰');
      expect(formatNumber(-12450000), '-۱۲٬۴۵۰٬۰۰۰');
    });

    test(
        'formats doubles with Persian decimal separator and thousands separator',
        () {
      expect(formatNumber(1234.5), '۱٬۲۳۴٫۵');
      expect(formatNumber(1234.0), '۱٬۲۳۴');
      expect(formatNumber(-500.25), '-۵۰۰٫۲۵');
    });

    test('formats numeric strings with or without existing separators', () {
      expect(formatNumber('12450000'), '۱۲٬۴۵۰٬۰۰۰');
      expect(formatNumber('12,450,000'), '۱۲٬۴۵۰٬۰۰۰');
      expect(formatNumber('12٬450٬000'), '۱۲٬۴۵۰٬۰۰۰');
      expect(formatNumber('-1500'), '-۱٬۵۰۰');
      expect(formatNumber('0'), '۰');
      expect(formatNumber(''), '');
      expect(formatNumber(null), '');
    });

    test('allows disabling thousands separator for years or codes', () {
      expect(formatNumber(1405, thousands: false), '۱۴۰۵');
      expect(formatNumber('1405', thousands: false), '۱۴۰۵');
      expect(formatNumber('1.0', thousands: false), '۱.۰');
    });
  });

  group('formatCount', () {
    test('formats count with Persian digits and unit', () {
      expect(formatCount(1, 'نقش'), '۱ نقش');
      expect(formatCount(3, 'مرحله'), '۳ مرحله');
      expect(formatCount(1, 'رقم'), '۱ رقم');
      expect(formatCount(0, 'مورد'), '۰ مورد');
      expect(formatCount(12, 'مورد ثبت‌شده'), '۱۲ مورد ثبت‌شده');
      expect(formatCount(11, 'فیلد'), '۱۱ فیلد');
      expect(formatCount(1000, 'سند'), '۱٬۰۰۰ سند');
    });

    test('formats count without unit', () {
      expect(formatCount(5), '۵');
      expect(formatCount(0), '۰');
      expect(formatCount('12'), '۱۲');
      expect(formatCount(null), '۰');
    });

    test('formats fractions and counters', () {
      expect(formatCount('0/500'), '۰/۵۰۰');
      expect(formatCounter(0, 500), '۰/۵۰۰');
      expect(formatCounter(15, 2000), '۱۵/۲۰۰۰');
    });
  });

  group('formatDateTimeJalali', () {
    test('formats DateTime with Jalali date and Persian time', () {
      final dt = DateTime(2026, 10, 7, 2, 12);
      expect(formatDateTimeJalali(dt), '۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲');
      expect(formatDateTimeJalali(dt, showTime: false), '۱۴۰۵/۰۷/۱۵');
    });

    test('formats ISO strings to Jalali with date and time', () {
      expect(formatDateTimeJalali('2026-10-07T02:12:00'), '۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲');
      expect(formatDateTimeJalali('2026-10-07 02:12:00'), '۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲');
      expect(formatDateTimeJalali('2026-10-07'), '۱۴۰۵/۰۷/۱۵');
      expect(formatDateTimeJalali('1976-04-12'), '۱۳۵۵/۰۱/۲۳');
      expect(formatDateTimeJalali('2026/10/17'), '۱۴۰۵/۰۷/۲۵');
      expect(formatDateTimeJalali('2026/10/07 – 02:12'), '۱۴۰۵/۰۷/۱۵ – ۰۲:۱۲');
      expect(formatDateTimeJalali(''), '');
      expect(formatDateTimeJalali(null), '');
    });

    test('formatDateJalali convenience helper returns date only', () {
      expect(formatDateJalali(DateTime(2026, 10, 7, 2, 12)), '۱۴۰۵/۰۷/۱۵');
      expect(formatDateJalali('2026-10-07T02:12:00'), '۱۴۰۵/۰۷/۱۵');
    });
  });

  group('formatPersianTime (time helper on jalali_date.dart)', () {
    test('formats time with Persian digits', () {
      expect(formatPersianTime(DateTime(2026, 10, 7, 2, 12)), '۰۲:۱۲');
      expect(formatPersianTime(DateTime(2026, 10, 7, 14, 5)), '۱۴:۰۵');
    });

    test('formats time from ISO string', () {
      expect(formatPersianTimeIso('2026-10-07T02:12:00'), '۰۲:۱۲');
      expect(formatPersianTimeIso('2026-10-07 14:05:00'), '۱۴:۰۵');
      expect(formatPersianTimeIso('2026-10-07'), '');
    });
  });
}
