import 'package:shamsi_date/shamsi_date.dart' as solar;

/// Solar Hijri (Jalali) calendar helpers for display in the Persian UI.
class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  factory JalaliDate.fromDateTime(DateTime value) {
    final date = solar.Jalali.fromDateTime(value);
    return JalaliDate(date.year, date.month, date.day);
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

String toLatinDigits(String value) => value.split('').map((character) {
      final persian = '۰۱۲۳۴۵۶۷۸۹'.indexOf(character);
      final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(character);
      return persian >= 0
          ? '$persian'
          : arabic >= 0
              ? '$arabic'
              : character;
    }).join();

/// Strict conversion through the shared maintained Jalali calendar library.
DateTime? parseJalaliDate(String value) {
  final match = RegExp(r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$')
      .firstMatch(toLatinDigits(value.trim()));
  if (match == null) return null;
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!);
  try {
    return solar.Jalali(year, month, day).toDateTime();
  } on solar.DateException {
    return null;
  }
}

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

String formatJalaliDateTime(DateTime value) {
  final local = value.toLocal();
  final date = toPersianDigits(JalaliDate.fromDateTime(local).format());
  final time = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${toPersianDigits(time)}، $date';
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

/// `۰۲:۱۲`
String formatPersianTime(DateTime value) {
  final local = value.toLocal();
  final time = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return toPersianDigits(time);
}

/// `۰۲:۱۲` from an ISO string, or empty if no time component.
String formatPersianTimeIso(String iso) {
  if (!RegExp(r'[Tt ]\d{2}:\d{2}').hasMatch(iso)) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  return formatPersianTime(date);
}
