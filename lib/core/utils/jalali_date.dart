/// Solar Hijri (Jalali) calendar helpers for display in the Persian UI.
class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  factory JalaliDate.fromDateTime(DateTime value) {
    var gy = value.year;
    final gm = value.month;
    final gd = value.day;
    var jy = gy > 1600 ? 979 : 0;
    gy -= gy > 1600 ? 1600 : 621;
    final gy2 = gm > 2 ? gy + 1 : gy;
    const monthDays = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    var days = 365 * gy +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) -
        80 +
        gd +
        monthDays[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
    return JalaliDate(jy, jm, jd);
  }

  final int year, month, day;

  static const monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  String get monthName => monthNames[month - 1];

  /// `1405/07/02`, with Latin digits.
  String format() =>
      '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
}

const _weekdays = {
  DateTime.saturday: 'شنبه',
  DateTime.sunday: 'یکشنبه',
  DateTime.monday: 'دوشنبه',
  DateTime.tuesday: 'سه‌شنبه',
  DateTime.wednesday: 'چهارشنبه',
  DateTime.thursday: 'پنجشنبه',
  DateTime.friday: 'جمعه',
};

String persianWeekday(DateTime value) => _weekdays[value.weekday]!;

String toPersianDigits(Object value) => value
    .toString()
    .replaceAllMapped(RegExp('[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);

/// `پنجشنبه ۲ مهر ۱۴۰۵`
String formatJalaliLong(DateTime value) {
  final date = JalaliDate.fromDateTime(value);
  return '${persianWeekday(value)} ${toPersianDigits(date.day)} '
      '${date.monthName} ${toPersianDigits(date.year)}';
}

String formatJalaliIso(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  return toPersianDigits(JalaliDate.fromDateTime(date).format());
}

String formatJalaliDateTimeIso(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final formatted = toPersianDigits(JalaliDate.fromDateTime(date).format());
  if (!RegExp(r'[Tt ]\d{2}').hasMatch(iso)) return formatted;
  final time = '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '$formatted - ${toPersianDigits(time)}';
}
