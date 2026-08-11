import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/workflow_notification.dart';
import '../../domain/repositories/workflow_notification_repository.dart';

class PreviewWorkflowNotificationRepository
    implements WorkflowNotificationRepository {
  PreviewWorkflowNotificationRepository(this._remote);
  final WorkflowNotificationRepository _remote;
  static const _readKey = 'asoud.preview.workflow_notifications.read';
  bool _offline = false;

  @override
  bool get isOfflinePreview => _offline;

  @override
  Future<List<WorkflowNotification>> getNotifications(
      {bool unreadOnly = false}) async {
    try {
      final result = await _remote.getNotifications(unreadOnly: unreadOnly);
      _offline = false;
      return result;
    } on ApiException catch (error) {
      if (!_isNetworkFailure(error)) rethrow;
      _offline = true;
      final read = (await SharedPreferences.getInstance())
              .getStringList(_readKey)
              ?.toSet() ??
          <String>{};
      final items = _samples
          .map((item) => item.copyWith(isRead: read.contains(item.id)))
          .where((item) => !unreadOnly || !item.isRead)
          .toList(growable: false);
      return items;
    }
  }

  @override
  Future<void> markRead(String notification) async {
    if (!_offline) {
      await _remote.markRead(notification);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final read = preferences.getStringList(_readKey)?.toSet() ?? <String>{};
    read.add(notification);
    await preferences.setStringList(_readKey, read.toList());
  }

  bool _isNetworkFailure(ApiException error) => const {
        ApiFailureKind.network,
        ApiFailureKind.timeout,
        ApiFailureKind.server,
      }.contains(error.kind);

  static final _samples = [
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-1',
      title: 'کار جدید به شما ارجاع شد',
      message: 'بررسی درخواست خرید لپ‌تاپ',
      instance: 'LOCAL-INSTANCE-1',
      createdAt: DateTime(2026, 8, 11, 9, 41),
      localOnly: true,
    ),
    WorkflowNotification(
      id: 'LOCAL-NOTIFICATION-2',
      title: 'درخواست برای اصلاح برگشت داده شد',
      message: 'لطفاً توضیحات درخواست را تکمیل کنید.',
      instance: 'LOCAL-INSTANCE-2',
      createdAt: DateTime(2026, 8, 10, 14, 20),
      localOnly: true,
    ),
  ];
}
