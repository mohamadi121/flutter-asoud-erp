/// Maps common IANA time zone identifiers to readable Persian descriptions
/// including their standard UTC offsets, e.g. «تهران (UTC+3:30)».
/// Unknown identifiers fall back to the raw time zone id.
String formatPersianTimeZone(String? timeZone) {
  if (timeZone == null || timeZone.trim().isEmpty) {
    return '';
  }
  final trimmed = timeZone.trim();
  final mapped = _commonIanaTimeZones[trimmed];
  if (mapped != null) {
    return mapped;
  }
  return trimmed;
}

/// Common IANA time zone IDs mapped to Persian name with UTC offset.
/// The specification explicitly asks for: «تهران (UTC+3:30)»
const _commonIanaTimeZones = <String, String>{
  // Iran & Middle East
  'Asia/Tehran': 'تهران (UTC+3:30)',
  'Asia/Dubai': 'دبی (UTC+4:00)',
  'Asia/Baghdad': 'بغداد (UTC+3:00)',
  'Asia/Riyadh': 'ریاض (UTC+3:00)',
  'Asia/Kabul': 'کابل (UTC+4:30)',
  'Asia/Baku': 'باکو (UTC+4:00)',
  'Asia/Yerevan': 'ایروان (UTC+4:00)',
  'Asia/Tbilisi': 'تفلیس (UTC+4:00)',
  'Asia/Muscat': 'مسقط (UTC+4:00)',
  'Asia/Kuwait': 'کویت (UTC+3:00)',
  'Asia/Doha': 'دوحه (UTC+3:00)',
  'Asia/Bahrain': 'بحرین (UTC+3:00)',
  'Asia/Damascus': 'دمشق (UTC+3:00)',
  'Asia/Beirut': 'بیروت (UTC+2:00)',
  'Asia/Amman': 'امان (UTC+3:00)',
  'Asia/Jerusalem': 'قدس (UTC+2:00)',

  // Asia / Central / East / South
  'Asia/Istanbul': 'استانبول (UTC+3:00)',
  'Europe/Istanbul': 'استانبول (UTC+3:00)',
  'Asia/Karachi': 'کراچی (UTC+5:00)',
  'Asia/Tashkent': 'تاشکند (UTC+5:00)',
  'Asia/Ashgabat': 'عشق‌آباد (UTC+5:00)',
  'Asia/Dushanbe': 'دوشنبه (UTC+5:00)',
  'Asia/Bishkek': 'بیشکک (UTC+6:00)',
  'Asia/Almaty': 'آلماتی (UTC+6:00)',
  'Asia/Kolkata': 'کلکته / دهلی نو (UTC+5:30)',
  'Asia/Calcutta': 'کلکته / دهلی نو (UTC+5:30)',
  'Asia/Dhaka': 'داکا (UTC+6:00)',
  'Asia/Bangkok': 'بانکوک (UTC+7:00)',
  'Asia/Jakarta': 'جاکارتا (UTC+7:00)',
  'Asia/Shanghai': 'شانگهای / پکن (UTC+8:00)',
  'Asia/Hong_Kong': 'هنگ‌کنگ (UTC+8:00)',
  'Asia/Singapore': 'سنگاپور (UTC+8:00)',
  'Asia/Kuala_Lumpur': 'کوالالامپور (UTC+8:00)',
  'Asia/Seoul': 'سئول (UTC+9:00)',
  'Asia/Tokyo': 'توکیو (UTC+9:00)',

  // Europe
  'Europe/London': 'لندن (UTC+0:00)',
  'Europe/Paris': 'پاریس (UTC+1:00)',
  'Europe/Berlin': 'برلین (UTC+1:00)',
  'Europe/Rome': 'رم (UTC+1:00)',
  'Europe/Madrid': 'مادرید (UTC+1:00)',
  'Europe/Amsterdam': 'آمستردام (UTC+1:00)',
  'Europe/Brussels': 'بروکسل (UTC+1:00)',
  'Europe/Vienna': 'وین (UTC+1:00)',
  'Europe/Stockholm': 'استکهلم (UTC+1:00)',
  'Europe/Oslo': 'اسلو (UTC+1:00)',
  'Europe/Copenhagen': 'کپنهاگ (UTC+1:00)',
  'Europe/Zurich': 'زوریخ (UTC+1:00)',
  'Europe/Athens': 'آتن (UTC+2:00)',
  'Europe/Helsinki': 'هلسینکی (UTC+2:00)',
  'Europe/Kyiv': 'کی‌یف (UTC+2:00)',
  'Europe/Moscow': 'مسکو (UTC+3:00)',

  // Americas
  'America/New_York': 'نیویورک (UTC-5:00)',
  'America/Chicago': 'شیکاگو (UTC-6:00)',
  'America/Denver': 'دنور (UTC-7:00)',
  'America/Los_Angeles': 'لس‌آنجلس (UTC-8:00)',
  'America/Toronto': 'تورنتو (UTC-5:00)',
  'America/Vancouver': 'ونکوور (UTC-8:00)',
  'America/Mexico_City': 'مکزیکوسیتی (UTC-6:00)',
  'America/Sao_Paulo': 'سائوپائولو (UTC-3:00)',
  'America/Buenos_Aires': 'بوئنوس‌آیرس (UTC-3:00)',

  // Australia & Pacific
  'Australia/Sydney': 'سیدنی (UTC+10:00)',
  'Australia/Melbourne': 'ملبورن (UTC+10:00)',
  'Pacific/Auckland': 'اوکلند (UTC+12:00)',

  // Africa
  'Africa/Cairo': 'قاهره (UTC+2:00)',
  'Africa/Johannesburg': 'ژوهانسبورگ (UTC+2:00)',

  // UTC / GMT
  'UTC': 'هماهنگ جهانی (UTC)',
  'GMT': 'گرینویچ (GMT)',
  'Etc/UTC': 'هماهنگ جهانی (UTC)',
  'Etc/GMT': 'گرینویچ (GMT)',
};
