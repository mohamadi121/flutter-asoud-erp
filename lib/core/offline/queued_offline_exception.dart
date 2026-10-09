/// Thrown by a write that could not reach the server but is safely queued on
/// this device. The queue sends it once the connection returns, so callers can
/// report «ذخیره شد» instead of an error.
class QueuedOfflineException implements Exception {
  const QueuedOfflineException({
    required this.localId,
    this.message = queuedFeedback,
  });

  static const queuedFeedback = 'ذخیره شد؛ پس از اتصال ارسال می‌شود';

  /// The queued row that will carry this write to the server.
  final String localId;
  final String message;

  @override
  String toString() => message;
}
