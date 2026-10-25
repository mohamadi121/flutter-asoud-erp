import '../../../core/utils/jalali_date.dart';

/// Validation shared by the admin initial-profile form. Every value is
/// accepted with Persian or Latin digits and returned normalised to Latin.
abstract final class IdentityValidators {
  /// `09123456789`, also accepted as `+98 912…`, `0098912…`, `98912…`, `912…`.
  /// Returns the normalised `09xxxxxxxxx`, or null when it is not valid.
  static String? normalizeMobile(String input) {
    var value = toLatinDigits(input)
        .replaceAll(RegExp(r'[\s\-().‌‏‎]'), '');
    if (value.startsWith('+98')) {
      value = '0${value.substring(3)}';
    } else if (value.startsWith('0098')) {
      value = '0${value.substring(4)}';
    } else if (value.startsWith('98') && value.length == 12) {
      value = '0${value.substring(2)}';
    } else if (value.startsWith('9') && value.length == 10) {
      value = '0$value';
    }
    return RegExp(r'^09[0-9]{9}$').hasMatch(value) ? value : null;
  }

  static String? mobile(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return 'شماره موبایل را وارد کنید.';
    return normalizeMobile(text) == null
        ? 'شماره موبایل معتبر نیست؛ مثل ۰۹۱۲۳۴۵۶۷۸۹'
        : null;
  }

  static String? required(String? input, String label) =>
      (input ?? '').trim().isEmpty ? '$label را وارد کنید.' : null;

  /// Optional field: empty is valid; otherwise 10 digits with the official
  /// control digit.
  static String? nationalId(String? input) {
    final text = toLatinDigits((input ?? '').trim());
    if (text.isEmpty) return null;
    if (!isValidNationalId(text)) return 'کد ملی معتبر نیست.';
    return null;
  }

  static bool isValidNationalId(String value) {
    final id = toLatinDigits(value.trim());
    if (!RegExp(r'^[0-9]{10}$').hasMatch(id)) return false;
    if (RegExp(r'^(\d)\1{9}$').hasMatch(id)) return false;
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(id[i]) * (10 - i);
    }
    final remainder = sum % 11;
    final check = int.parse(id[9]);
    return remainder < 2 ? check == remainder : check == 11 - remainder;
  }

  /// Optional field: empty is valid; otherwise `name@host.tld`.
  static String? email(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return null;
    final valid = RegExp(
            r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$")
        .hasMatch(text);
    return valid ? null : 'ایمیل معتبر نیست.';
  }
}

/// Password policy mirrored from the server (spec section 21).
abstract final class PasswordPolicy {
  static const minLength = 12;

  static String? newPassword(String? value, {String? current}) {
    final text = value ?? '';
    if (text.isEmpty) return 'رمز عبور جدید را وارد کنید.';
    if (text.length < minLength) {
      return 'رمز عبور جدید باید دست‌کم ${toPersianDigits(minLength)} نویسه باشد.';
    }
    if (current != null && current.isNotEmpty && text == current) {
      return 'رمز عبور جدید نباید با رمز فعلی یکسان باشد.';
    }
    return null;
  }

  static String? repeat(String? value, String newPassword) =>
      (value ?? '').isEmpty
          ? 'تکرار رمز عبور جدید را وارد کنید.'
          : value == newPassword
              ? null
              : 'تکرار رمز عبور با رمز جدید یکسان نیست.';
}
