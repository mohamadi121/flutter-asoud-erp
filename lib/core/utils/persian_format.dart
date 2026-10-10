import 'jalali_date.dart';

export 'jalali_date.dart'
    show
        JalaliDate,
        toPersianDigits,
        toLatinDigits,
        parseJalaliDate,
        formatJalaliLong,
        formatJalaliIso,
        formatJalaliDateTime,
        formatJalaliDateTimeIso,
        formatPersianTime,
        formatPersianTimeIso;

/// Persian thousands separator: «٬» (U+066C, Arabic Thousands Separator).
const String persianThousandsSeparator = '٬';

/// Persian decimal separator: «٫» (U+066B, Arabic Decimal Separator).
const String persianDecimalSeparator = '٫';

/// Formats a number ([num] or [String]) with Persian digits ('۰'..'۹')
/// and optional Persian thousands separator («٬»).
///
/// If [thousands] is true (default), groups the integer part into triplets with «٬».
/// Handles negative numbers, decimals, and existing formatted numbers with commas.
String formatNumber(Object? value, {bool thousands = true}) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';

  // Normalize string: convert Persian/Arabic digits to Latin for numeric processing
  final latin = toLatinDigits(raw)
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll(' ', '');

  // Check if it's a valid number format
  final match = RegExp(r'^([+-])?(\d+)(?:\.(\d+))?$').firstMatch(latin);
  if (match == null) {
    // If not a pure number, convert any digits present to Persian
    return toPersianDigits(raw);
  }

  final sign = match.group(1) == '-' ? '-' : '';
  final intDigits = match.group(2)!;
  final decDigits = match.group(3);

  final String formattedInt;
  if (!thousands || intDigits.length <= 3) {
    formattedInt = toPersianDigits(intDigits);
  } else {
    final buffer = StringBuffer();
    final len = intDigits.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(persianThousandsSeparator);
      }
      buffer.write(intDigits[i]);
    }
    formattedInt = toPersianDigits(buffer.toString());
  }

  // If decimal part exists
  if (decDigits != null && decDigits.isNotEmpty) {
    if (value is double && value == value.truncateToDouble()) {
      return '$sign$formattedInt';
    }
    final formattedDec = toPersianDigits(decDigits);
    final sep = thousands ? persianDecimalSeparator : '.';
    return '$sign$formattedInt$sep$formattedDec';
  }

  return '$sign$formattedInt';
}

/// Formats a count with Persian digits, optional thousands grouping,
/// and an optional [unit] label (e.g. `formatCount(3, 'مرحله')` -> `'۳ مرحله'`).
String formatCount(Object? count, [String? unit]) {
  if (count == null) {
    return unit != null && unit.isNotEmpty ? '۰ $unit' : '۰';
  }

  final String formatted;
  if (count is num) {
    formatted = formatNumber(count);
  } else {
    final str = count.toString().trim();
    if (str.contains('/')) {
      formatted = toPersianDigits(str);
    } else {
      final parsed = num.tryParse(
          toLatinDigits(str).replaceAll(',', '').replaceAll('٬', ''));
      if (parsed != null) {
        formatted = formatNumber(parsed);
      } else {
        formatted = toPersianDigits(str);
      }
    }
  }

  return unit != null && unit.isNotEmpty ? '$formatted $unit' : formatted;
}

/// Formats a counter fraction e.g. `formatCounter(0, 500)` -> `'۰/۵۰۰'`.
String formatCounter(int current, int? max) =>
    '${toPersianDigits(current)}/${toPersianDigits(max ?? 0)}';

/// Formats a [DateTime] or date [String] into Solar Hijri (Jalali) display format.
///
/// Wraps [jalali_date.dart]. If [showTime] is null, includes the time when the input
/// has non-zero hours/minutes or contains a time component in its ISO string.
String formatDateTimeJalali(
  Object? value, {
  bool? showTime,
  String timeSeparator = ' – ',
}) {
  if (value == null) return '';

  if (value is DateTime) {
    final local = value.toLocal();
    final jalali = JalaliDate.fromDateTime(local);
    final dateStr = toPersianDigits(jalali.format());
    final hasTime = local.hour != 0 || local.minute != 0 || local.second != 0;
    final includeTime = showTime ?? hasTime;
    if (includeTime) {
      return '$dateStr$timeSeparator${formatPersianTime(local)}';
    }
    return dateStr;
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return '';

  // Try parsing ISO/Gregorian date strings (normalizing slashes to dashes)
  final normalized =
      raw.replaceAll(' – ', ' ').replaceAll(' - ', ' ').replaceAll('/', '-');

  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    final local = parsed.toLocal();
    final jalali = JalaliDate.fromDateTime(local);
    final dateStr = toPersianDigits(jalali.format());
    final hasTime = RegExp(r'[Tt ]\d{2}:\d{2}').hasMatch(raw);
    final includeTime = showTime ?? hasTime;
    if (includeTime) {
      return '$dateStr$timeSeparator${formatPersianTime(local)}';
    }
    return dateStr;
  }

  // If already Jalali, ensure Persian digits
  return toPersianDigits(raw);
}

/// Convenience helper: formats a date ([DateTime] or [String]) to Jalali without time.
String formatDateJalali(Object? value) =>
    formatDateTimeJalali(value, showTime: false);
