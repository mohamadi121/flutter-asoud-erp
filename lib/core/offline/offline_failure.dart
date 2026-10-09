import '../network/api_exception.dart';
import 'queued_offline_exception.dart';

/// Status codes the server rejects on its own terms. Replaying such a write
/// unchanged only wastes the queue, so it waits for the user instead.
const terminalOfflineStatusCodes = <int>{400, 403, 409, 417};

/// Whether the write can still succeed later without any change from the user.
/// A [QueuedOfflineException] qualifies: the write is on the device already.
bool isRetryableOfflineFailure(Object error) {
  if (error is QueuedOfflineException) return true;
  if (error is! ApiException) return false;
  if (terminalOfflineStatusCodes.contains(error.statusCode)) return false;
  return const {
    ApiFailureKind.network,
    ApiFailureKind.timeout,
    ApiFailureKind.server,
  }.contains(error.kind);
}

/// Translates raw error strings or exception details into clean Persian sentences
/// per failure kind (validation, permission, network, server), avoiding raw Dart text.
String persianSyncErrorMessage(String? rawError) {
  if (rawError == null || rawError.trim().isEmpty) {
    return 'خطای نامشخص سرور';
  }
  final text = rawError.trim();
  if (text.contains('ApiFailureKind.validation') ||
      text.contains('417') ||
      text.contains('422') ||
      text.contains('400')) {
    return 'اطلاعات ارسال‌شده معتبر نیست و باید اصلاح شود.';
  }
  if (text.contains('ApiFailureKind.forbidden') ||
      text.contains('ApiFailureKind.unauthenticated') ||
      text.contains('403') ||
      text.contains('401')) {
    return 'دسترسی لازم برای انجام این عملیات وجود ندارد.';
  }
  if (text.contains('ApiFailureKind.network') ||
      text.contains('ApiFailureKind.timeout') ||
      text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('TimeoutException')) {
    return 'ارتباط با سرور برقرار نشد؛ اتصال شبکه را بررسی کنید.';
  }
  if (text.contains('ApiFailureKind.server') ||
      text.contains('ApiFailureKind.protocol') ||
      text.contains('500') ||
      text.contains('502') ||
      text.contains('503') ||
      text.contains('504')) {
    return 'سرور در حال حاضر قادر به پاسخ‌گویی نیست؛ لطفاً بعداً تلاش کنید.';
  }
  if (text.startsWith('ApiException(') || text.startsWith('Exception:')) {
    return 'خطای پردازش در سرور رخ داد؛ لطفاً بعداً تلاش کنید.';
  }
  return text;
}

/// The Persian text a user should read for a write that failed.
String offlineFailureMessage(Object error) {
  if (error is ApiException) {
    return switch (error.kind) {
      ApiFailureKind.validation => _cleanMessage(
          error.message, 'اطلاعات ارسال‌شده معتبر نیست و باید اصلاح شود.'),
      ApiFailureKind.forbidden ||
      ApiFailureKind.unauthenticated =>
        _cleanMessage(
            error.message, 'دسترسی لازم برای انجام این عملیات وجود ندارد.'),
      ApiFailureKind.network || ApiFailureKind.timeout => _cleanMessage(
          error.message,
          'ارتباط با سرور برقرار نشد؛ اتصال شبکه را بررسی کنید.'),
      ApiFailureKind.server || ApiFailureKind.protocol => _cleanMessage(
          error.message,
          'سرور در حال حاضر قادر به پاسخ‌گویی نیست؛ لطفاً بعداً تلاش کنید.'),
      _ => _cleanMessage(
          error.message, 'خطای پردازش در سرور رخ داد؛ لطفاً بعداً تلاش کنید.'),
    };
  }
  if (error is QueuedOfflineException) return error.message;
  return persianSyncErrorMessage(error.toString());
}

String _cleanMessage(String message, String fallback) {
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('ApiException(') ||
      trimmed.startsWith('Exception:')) {
    return fallback;
  }
  return trimmed;
}

/// Whether the error means "safely queued, will replay automatically".
bool isQueuedOffline(Object error) => error is QueuedOfflineException;
