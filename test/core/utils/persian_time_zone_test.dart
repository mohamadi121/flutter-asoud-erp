import 'package:asoud_erp/core/utils/persian_time_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPersianTimeZone', () {
    test('maps Asia/Tehran to تهران (UTC+3:30)', () {
      expect(formatPersianTimeZone('Asia/Tehran'), 'تهران (UTC+3:30)');
    });

    test('maps America/New_York to نیویورک (UTC-5:00)', () {
      expect(formatPersianTimeZone('America/New_York'), 'نیویورک (UTC-5:00)');
    });

    test('maps common regions across continents', () {
      expect(formatPersianTimeZone('Asia/Dubai'), 'دبی (UTC+4:00)');
      expect(formatPersianTimeZone('Europe/London'), 'لندن (UTC+0:00)');
      expect(formatPersianTimeZone('Europe/Paris'), 'پاریس (UTC+1:00)');
      expect(formatPersianTimeZone('Asia/Tokyo'), 'توکیو (UTC+9:00)');
      expect(formatPersianTimeZone('UTC'), 'هماهنگ جهانی (UTC)');
    });

    test('falls back to raw id for unknown time zones', () {
      expect(formatPersianTimeZone('Custom/NonExistent_Zone'), 'Custom/NonExistent_Zone');
      expect(formatPersianTimeZone('Mars/Curiosity'), 'Mars/Curiosity');
    });

    test('handles null and whitespace gracefully', () {
      expect(formatPersianTimeZone(null), '');
      expect(formatPersianTimeZone(''), '');
      expect(formatPersianTimeZone('   '), '');
      expect(formatPersianTimeZone('  Asia/Tehran  '), 'تهران (UTC+3:30)');
    });
  });
}
