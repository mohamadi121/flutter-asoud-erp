import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = 'عملیات در سرور تکمیل نشد.';

  group('persianOrFallback', () {
    test('a Persian sentence is returned unchanged', () {
      expect(persianOrFallback('سند این درخواست قابل تلاش مجدد نیست.', fallback),
          'سند این درخواست قابل تلاش مجدد نیست.');
    });

    test('an English-only sentence is replaced by the fallback', () {
      expect(persianOrFallback('This request is not retryable.', fallback),
          fallback);
    });

    test('a mixed sentence with a code keeps the Persian part', () {
      expect(
          persianOrFallback('درخواست REQ-0001 در حال پردازش است.', fallback),
          'درخواست REQ-0001 در حال پردازش است.');
    });

    test('an empty sentence is replaced by the fallback', () {
      expect(persianOrFallback('', fallback), fallback);
    });

    test('a whitespace-only sentence is replaced by the fallback', () {
      expect(persianOrFallback('   \n\t ', fallback), fallback);
    });

    test('a null sentence is replaced by the fallback', () {
      expect(persianOrFallback(null, fallback), fallback);
    });

    test('a sentence with only Latin letters and digits is replaced', () {
      expect(persianOrFallback('REQ-0001', fallback), fallback);
    });
  });
}
