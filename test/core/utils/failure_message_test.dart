import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('خطای اعتبارسنجی: جملهٔ فارسی سرور به‌جای پیام عمومی نمایش داده می‌شود',
      () {
    const failure = ApiException(
        kind: ApiFailureKind.validation,
        message: 'ASOUD setup does not exist for this company',
        statusCode: 417);
    expect(
        failureMessage(failure),
        'ASOUD setup does not exist for this company',
        reason: 'دلیل واقعی سرور باید به کاربر برسد، نه «اطلاعات واردشده را بررسی کنید.»');
    expect(failureMessage(failure), isNot('اطلاعات واردشده را بررسی کنید.'));
  });

  test('خطای اعتبارسنجی بدون پیام سرور به جملهٔ عمومی برمی‌گردد', () {
    const failure = ApiException(
        kind: ApiFailureKind.validation, message: '', statusCode: 417);
    expect(failureMessage(failure), 'اطلاعات واردشده را بررسی کنید.');
  });

  test('failureDetail برای خطاهای غیر از اعتبارسنجی همان failureMessage است',
      () {
    const network = ApiException(kind: ApiFailureKind.network, message: 'x');
    expect(failureDetail(network), failureMessage(network));
    const validation = ApiException(
        kind: ApiFailureKind.validation,
        message: 'شرکت انتخاب‌شده وجود ندارد.',
        statusCode: 417);
    expect(failureDetail(validation), 'شرکت انتخاب‌شده وجود ندارد.');
  });

  test('خطای دسترسی همچنان پیام ثابت فارسی دارد', () {
    const failure = ApiException(
        kind: ApiFailureKind.forbidden, message: 'Not permitted',
        statusCode: 403);
    expect(failureMessage(failure), forbiddenFailureMessage);
  });
}
