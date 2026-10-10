import '../network/api_exception.dart';

/// A user-facing explanation for failures returned by the server or network.
String failureMessage(Object? failure) {
  if (failure is! ApiException) {
    return 'دریافت اطلاعات ممکن نشد. دوباره تلاش کنید.';
  }
  return switch (failure.kind) {
    ApiFailureKind.invalidCredentials => 'نام کاربری یا گذرواژه درست نیست.',
    ApiFailureKind.unauthenticated =>
      'نشست شما پایان یافته است. دوباره وارد شوید.',
    ApiFailureKind.forbidden => 'اجازه دسترسی به این بخش را ندارید',
    ApiFailureKind.validation => 'اطلاعات واردشده را بررسی کنید.',
    ApiFailureKind.conflict =>
      'این اطلاعات قبلاً تغییر کرده است. دوباره بررسی کنید.',
    ApiFailureKind.rateLimited =>
      'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.',
    ApiFailureKind.timeout => 'پاسخ سرور طول کشید. دوباره تلاش کنید.',
    ApiFailureKind.network =>
      'ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.',
    ApiFailureKind.server => 'خطایی در سرور رخ داد. کمی بعد دوباره تلاش کنید.',
    ApiFailureKind.protocol =>
      'اطلاعات موردنظر پیدا نشد یا پاسخ سرور قابل پردازش نیست.',
    ApiFailureKind.cancelled => 'عملیات لغو شد.',
  };
}

bool failureCanRetry(Object? failure) =>
    failure is! ApiException ||
    !{
      ApiFailureKind.forbidden,
      ApiFailureKind.unauthenticated,
      ApiFailureKind.validation,
      ApiFailureKind.conflict,
      ApiFailureKind.cancelled,
    }.contains(failure.kind);
