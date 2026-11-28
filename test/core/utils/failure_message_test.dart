import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('خطای اعتبارسنجی: جملهٔ فارسی سرور به‌جای پیام عمومی نمایش داده می‌شود',
      () {
    const failure = ApiException(
        kind: ApiFailureKind.validation,
        message: 'شرکت انتخاب‌شده وجود ندارد.',
        statusCode: 417);
    expect(
        failureMessage(failure),
        'شرکت انتخاب‌شده وجود ندارد.',
        reason: 'دلیل واقعی فارسی سرور باید به کاربر برسد');
    expect(failureMessage(failure), isNot('اطلاعات واردشده را بررسی کنید.'));
  });

  test('خطای اعتبارسنجی انگلیسیِ خالص به جملهٔ عمومی برمی‌گردد', () {
    const failure = ApiException(
        kind: ApiFailureKind.validation,
        message: 'ASOUD setup does not exist for this company',
        statusCode: 417);
    expect(
        failureMessage(failure),
        'اطلاعات واردشده را بررسی کنید.',
        reason: 'هر شکست باید جملهٔ فارسی باشد؛ متن انگلیسیِ خالص نمایش داده نمی‌شود');
  });

  test('متن ترکیبی (فارسی با کلمهٔ انگلیسی یا کد) به‌صورت خام نمایش داده می‌شود',
      () {
    const failure = ApiException(
        kind: ApiFailureKind.validation,
        message: 'درخواست REQ-0001 هنوز در انتظار است.',
        statusCode: 417);
    expect(failureMessage(failure), 'درخواست REQ-0001 هنوز در انتظار است.');
  });

  test('خطای اعتبارسنجی بدون پیام سرور به جملهٔ عمومی برمی‌گردد', () {
    const failure = ApiException(
        kind: ApiFailureKind.validation, message: '', statusCode: 417);
    expect(failureMessage(failure), 'اطلاعات واردشده را بررسی کنید.');
  });

  test('خطای اعتبارسنجی با پیام فقط فاصله به جملهٔ عمومی برمی‌گردد', () {
    const failure = ApiException(
        kind: ApiFailureKind.validation, message: '   ', statusCode: 417);
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
