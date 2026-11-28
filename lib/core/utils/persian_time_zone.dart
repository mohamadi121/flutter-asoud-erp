import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import 'jalali_date.dart';

bool _timeZonesInitialized = false;

void _ensureTimeZonesInitialized() {
  if (!_timeZonesInitialized) {
    try {
      zones.initializeTimeZones();
      _timeZonesInitialized = true;
    } catch (_) {
      // Ignored: fallback logic will handle uninitialized or failed state
    }
  }
}

/// Computes the current UTC offset string formatted in Persian digits, e.g. `UTC+۳:۳۰` or `UTC-۴:۰۰`.
/// Returns null if timezone offset cannot be determined.
String? _computeUtcOffset(String timeZoneId, DateTime at) {
  _ensureTimeZonesInitialized();
  try {
    final location = tz.getLocation(timeZoneId);
    // tz.TZDateTime represents the instant in the given location
    final tzDate = tz.TZDateTime.from(at, location);
    final offsetMillis = tzDate.timeZoneOffset.inMilliseconds;
    final isNegative = offsetMillis < 0;
    final absMinutes = (offsetMillis.abs() / 60000).round();
    final hours = absMinutes ~/ 60;
    final minutes = absMinutes % 60;

    final sign = isNegative ? '-' : '+';
    final minuteStr = minutes.toString().padLeft(2, '0');
    final rawFormatted = 'UTC$sign$hours:$minuteStr';
    return toPersianDigits(rawFormatted);
  } catch (_) {
    return null;
  }
}

/// Maps IANA time zone identifiers to readable Persian descriptions
/// including their computed current UTC offsets, e.g. «تهران (UTC+۳:۳۰)».
/// If the time zone name is unknown, returns «منطقه زمانی نامشخص (UTC+...)» or «منطقه زمانی نامشخص».
String formatPersianTimeZone(String? timeZone, {DateTime? now}) {
  if (timeZone == null || timeZone.trim().isEmpty) {
    return '';
  }
  final trimmed = timeZone.trim();
  final at = now ?? DateTime.now();

  final persianName = _persianCityNames[trimmed];
  final offset = _computeUtcOffset(trimmed, at);

  if (persianName != null) {
    // Special UTC / GMT cases
    if (trimmed == 'UTC' || trimmed == 'GMT' || trimmed == 'Etc/UTC' || trimmed == 'Etc/GMT') {
      return persianName;
    }
    if (offset != null) {
      return '$persianName ($offset)';
    }
    return persianName;
  }

  // Unknown ID fallback
  if (offset != null) {
    return 'منطقه زمانی نامشخص ($offset)';
  }
  return 'منطقه زمانی نامشخص';
}

/// Common IANA time zone IDs mapped to their Persian names without hard-coded offsets.
const _persianCityNames = <String, String>{
  // Iran & Middle East
  'Asia/Tehran': 'تهران',
  'Asia/Dubai': 'دبی',
  'Asia/Baghdad': 'بغداد',
  'Asia/Riyadh': 'ریاض',
  'Asia/Kabul': 'کابل',
  'Asia/Baku': 'باکو',
  'Asia/Yerevan': 'ایروان',
  'Asia/Tbilisi': 'تفلیس',
  'Asia/Muscat': 'مسقط',
  'Asia/Kuwait': 'کویت',
  'Asia/Doha': 'دوحه',
  'Asia/Bahrain': 'بحرین',
  'Asia/Damascus': 'دمشق',
  'Asia/Beirut': 'بیروت',
  'Asia/Amman': 'امان',
  'Asia/Jerusalem': 'قدس',

  // Asia / Central / East / South
  'Asia/Kathmandu': 'کاتماندو',
  'Asia/Katmandu': 'کاتماندو',
  'Asia/Istanbul': 'استانبول',
  'Europe/Istanbul': 'استانبول',
  'Asia/Karachi': 'کراچی',
  'Asia/Tashkent': 'تاشکند',
  'Asia/Ashgabat': 'عشق‌آباد',
  'Asia/Dushanbe': 'دوشنبه',
  'Asia/Bishkek': 'بیشکک',
  'Asia/Almaty': 'آلماتی',
  'Asia/Kolkata': 'کلکته / دهلی نو',
  'Asia/Calcutta': 'کلکته / دهلی نو',
  'Asia/Dhaka': 'داکا',
  'Asia/Bangkok': 'بانکوک',
  'Asia/Jakarta': 'جاکارتا',
  'Asia/Shanghai': 'شانگهای / پکن',
  'Asia/Hong_Kong': 'هنگ‌کنگ',
  'Asia/Singapore': 'سنگاپور',
  'Asia/Kuala_Lumpur': 'کوالالامپور',
  'Asia/Seoul': 'سئول',
  'Asia/Tokyo': 'توکیو',

  // Europe
  'Europe/London': 'لندن',
  'Europe/Paris': 'پاریس',
  'Europe/Berlin': 'برلین',
  'Europe/Rome': 'رم',
  'Europe/Madrid': 'مادرید',
  'Europe/Amsterdam': 'آمستردام',
  'Europe/Brussels': 'بروکسل',
  'Europe/Vienna': 'وین',
  'Europe/Stockholm': 'استکهلم',
  'Europe/Oslo': 'اسلو',
  'Europe/Copenhagen': 'کپنهاگ',
  'Europe/Zurich': 'زوریخ',
  'Europe/Athens': 'آتن',
  'Europe/Helsinki': 'هلسینکی',
  'Europe/Kyiv': 'کی‌یف',
  'Europe/Moscow': 'مسکو',

  // Americas
  'America/New_York': 'نیویورک',
  'America/Chicago': 'شیکاگو',
  'America/Denver': 'دنور',
  'America/Los_Angeles': 'لس‌آنجلس',
  'America/Toronto': 'تورنتو',
  'America/Vancouver': 'ونکوور',
  'America/Mexico_City': 'مکزیکوسیتی',
  'America/Sao_Paulo': 'سائوپائولو',
  'America/Buenos_Aires': 'بوئنوس‌آیرس',

  // Australia & Pacific
  'Australia/Sydney': 'سیدنی',
  'Australia/Melbourne': 'ملبورن',
  'Pacific/Auckland': 'اوکلند',

  // Africa
  'Africa/Cairo': 'قاهره',
  'Africa/Johannesburg': 'ژوهانسبورگ',

  // UTC / GMT
  'UTC': 'هماهنگ جهانی (UTC)',
  'GMT': 'گرینویچ (GMT)',
  'Etc/UTC': 'هماهنگ جهانی (UTC)',
  'Etc/GMT': 'گرینویچ (GMT)',
};
