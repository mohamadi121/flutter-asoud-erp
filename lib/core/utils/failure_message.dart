import '../network/api_exception.dart';

const _genericFailure = 'دریافت اطلاعات ممکن نشد. دوباره تلاش کنید.';

/// The Persian reason shown when the server refuses access to a section.
/// Exposed so callers that only keep the localised string can still detect
/// an authorization failure (see [failureIsForbidden]).
const forbiddenFailureMessage = 'اجازه دسترسی به این بخش را ندارید';

/// The reason shown when the server sends a body larger than the client will
/// buffer (see the response-size cap in `frappe_client.dart`).
const oversizedResponseFailureMessage = 'پاسخ سرور بیش از حد بزرگ است.';

/// A user-facing explanation for failures returned by the server or network.
///
/// Accepts an [ApiException] or a non-empty string. Strings are passed through
/// unchanged so cubits that already format a specific Persian reason keep their
/// wording instead of being replaced by the generic message.
String failureMessage(Object? failure) {
  if (failure is String) {
    final message = failure.trim();
    return message.isEmpty ? _genericFailure : message;
  }
  if (failure is! ApiException) {
    return _genericFailure;
  }
  return switch (failure.kind) {
    ApiFailureKind.invalidCredentials => 'نام کاربری یا گذرواژه درست نیست.',
    ApiFailureKind.unauthenticated =>
      'نشست شما پایان یافته است. دوباره وارد شوید.',
    ApiFailureKind.forbidden => forbiddenFailureMessage,
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
    ApiFailureKind.responseTooLarge => oversizedResponseFailureMessage,
  };
}

/// Whether the failure was an authorization refusal. Works both for a raw
/// [ApiException] and for a message string produced by [failureMessage].
bool failureIsForbidden(Object? failure) =>
    (failure is ApiException &&
        failure.kind == ApiFailureKind.forbidden) ||
    (failure is String && failure.trim() == forbiddenFailureMessage);

bool failureCanRetry(Object? failure) {
  if (failure is String) {
    return failure.trim() != forbiddenFailureMessage;
  }
  return failure is! ApiException ||
      !{
        ApiFailureKind.forbidden,
        ApiFailureKind.unauthenticated,
        ApiFailureKind.validation,
        ApiFailureKind.conflict,
        ApiFailureKind.cancelled,
      }.contains(failure.kind);
}
