import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/workflow_notification.dart';
import '../../domain/repositories/workflow_notification_repository.dart';
import '../demo/task_notification_demo_data.dart';

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
      final items = demoNotifications()
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
}
