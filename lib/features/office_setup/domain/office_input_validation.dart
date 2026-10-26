import '../../../core/utils/jalali_date.dart';
import '../../auth/domain/identity_validators.dart';

/// Office form validation mirrored by services/office_validation.py.
abstract final class OfficeInputValidation {
  static String digits(String value) => toLatinDigits(value.trim());

  static String? nationalId(String value, {required bool legal}) {
    final code = digits(value);
    if (code.isEmpty) return null;
    if (!RegExp(legal ? r'^[0-9]{11}$' : r'^[0-9]{10}$').hasMatch(code)) {
      return legal
          ? 'شناسه ملی باید دقیقاً ۱۱ رقم باشد.'
          : 'کد ملی باید دقیقاً ۱۰ رقم باشد.';
    }
    if (!legal) return IdentityValidators.nationalId(code);
    if (RegExp(r'^(\d)\1{10}$').hasMatch(code) ||
        int.parse(code.substring(3, 9)) == 0) {
      return 'شناسه ملی حقوقی معتبر نیست.';
    }
    const weights = [29, 27, 23, 19, 17];
    final offset = int.parse(code[9]) + 2;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (int.parse(code[i]) + offset) * weights[i % 5];
    }
    final remainder = sum % 11;
    return int.parse(code[10]) == (remainder == 10 ? 0 : remainder)
        ? null
        : 'شناسه ملی حقوقی معتبر نیست.';
  }

  static String? mobile(String value) {
    final text = digits(value);
    return text.isEmpty || RegExp(r'^09[0-9]{9}$').hasMatch(text)
        ? null
        : 'شماره موبایل باید ۱۱ رقم باشد و با ۰۹ شروع شود.';
  }

  static String? postalCode(String value) {
    final text = digits(value);
    return text.isEmpty || RegExp(r'^[0-9]{10}$').hasMatch(text)
        ? null
        : 'کد پستی باید ۱۰ رقم باشد.';
  }

  static String? website(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (RegExp(r'\s').hasMatch(text)) return null;
    final normalized = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty) {
      return null;
    }
    final labels = uri.host.split('.');
    if (labels.length < 2 ||
        labels.any((label) =>
            !RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
                .hasMatch(label))) {
      return null;
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
    return normalized;
  }
}
