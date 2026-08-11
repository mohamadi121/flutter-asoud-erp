import '../entities/workflow_notification.dart';

abstract interface class WorkflowNotificationRepository {
  bool get isOfflinePreview;
  Future<List<WorkflowNotification>> getNotifications(
      {bool unreadOnly = false});
  Future<void> markRead(String notification);
}
