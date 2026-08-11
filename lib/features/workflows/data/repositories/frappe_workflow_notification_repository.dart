import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/workflow_notification.dart';
import '../../domain/repositories/workflow_notification_repository.dart';

class FrappeWorkflowNotificationRepository
    implements WorkflowNotificationRepository {
  const FrappeWorkflowNotificationRepository(this._client);
  final FrappeClient _client;

  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowNotification>> getNotifications(
      {bool unreadOnly = false}) async {
    final data = await _client.callAsoudMethod(
      'asoud_erp.api.v1.workflow_runtime.list_my_workflow_notifications',
      data: {'unread_only': unreadOnly ? 1 : 0},
    );
    if (data is! List) {
      throw StateError('Invalid workflow notification response');
    }
    return data.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WorkflowNotification(
        id: item['name']?.toString() ?? '',
        title: item['subject']?.toString() ?? '',
        message: item['email_content']?.toString() ?? '',
        instance: item['document_name']?.toString() ?? '',
        isRead: item['read'] == 1 || item['read'] == true,
        createdAt: DateTime.tryParse(item['creation']?.toString() ?? ''),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> markRead(String notification) => _client.callAsoudMethod(
        'asoud_erp.api.v1.workflow_runtime.mark_workflow_notification_read',
        data: {'notification': notification},
      );
}
