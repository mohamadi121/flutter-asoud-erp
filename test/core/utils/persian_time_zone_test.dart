import 'package:asoud_erp/core/utils/persian_time_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPersianTimeZone', () {
    test('maps Asia/Tehran to تهران (UTC+۳:۳۰) consistently regardless of season', () {
      final winter = DateTime(2026, 1, 15);
      final summer = DateTime(2026, 7, 15);
      expect(formatPersianTimeZone('Asia/Tehran', now: winter), 'تهران (UTC+۳:۳۰)');
      expect(formatPersianTimeZone('Asia/Tehran', now: summer), 'تهران (UTC+۳:۳۰)');
    });

    test('computes DST correctly for America/New_York (UTC-5 in winter, UTC-4 in summer)', () {
      final winter = DateTime(2026, 1, 15);
      final summer = DateTime(2026, 7, 15);
      expect(formatPersianTimeZone('America/New_York', now: winter), 'نیویورک (UTC-۵:۰۰)');
      expect(formatPersianTimeZone('America/New_York', now: summer), 'نیویورک (UTC-۴:۰۰)');
    });

    test('computes half-hour offset for Asia/Kolkata (UTC+۵:۳۰)', () {
      final date = DateTime(2026, 4, 1);
      expect(formatPersianTimeZone('Asia/Kolkata', now: date), 'کلکته / دهلی نو (UTC+۵:۳۰)');
    });

    test('computes 45-minute offset for Asia/Kathmandu (UTC+۵:۴۵)', () {
      final date = DateTime(2026, 4, 1);
      expect(formatPersianTimeZone('Asia/Kathmandu', now: date), 'کاتماندو (UTC+۵:۴۵)');
    });

    test('maps common regions across continents with Persian digits in offset', () {
      final winter = DateTime(2026, 1, 15);
      expect(formatPersianTimeZone('Asia/Dubai', now: winter), 'دبی (UTC+۴:۰۰)');
      expect(formatPersianTimeZone('Europe/London', now: winter), 'لندن (UTC+۰:۰۰)');
      expect(formatPersianTimeZone('Asia/Tokyo', now: winter), 'توکیو (UTC+۹:۰۰)');
      expect(formatPersianTimeZone('UTC', now: winter), 'هماهنگ جهانی (UTC)');
      expect(formatPersianTimeZone('GMT', now: winter), 'گرینویچ (GMT)');
    });

    test('handles unknown id with computable offset as منطقه زمانی نامشخص (UTC...) and non-computable as منطقه زمانی نامشخص', () {
      final date = DateTime(2026, 1, 15);
      // Valid IANA timezone not in _persianCityNames map (e.g. Pacific/Fiji or America/Phoenix)
      expect(
        formatPersianTimeZone('America/Phoenix', now: date),
        'منطقه زمانی نامشخص (UTC-۷:۰۰)',
      );
      // Completely bogus ID
      expect(
        formatPersianTimeZone('Custom/NonExistent_Zone', now: date),
        'منطقه زمانی نامشخص',
      );
      expect(
        formatPersianTimeZone('Mars/Curiosity', now: date),
        'منطقه زمانی نامشخص',
      );
    });

    test('handles null and whitespace gracefully', () {
      expect(formatPersianTimeZone(null), '');
      expect(formatPersianTimeZone(''), '');
      expect(formatPersianTimeZone('   '), '');
      final date = DateTime(2026, 1, 15);
      expect(formatPersianTimeZone('  Asia/Tehran  ', now: date), 'تهران (UTC+۳:۳۰)');
    });
  });
}
