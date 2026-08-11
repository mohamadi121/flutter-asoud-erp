import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/workflows/data/repositories/preview_workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/workflow_notification.dart';
import 'package:asoud_erp/features/workflows/domain/repositories/workflow_notification_repository.dart';
import 'package:asoud_erp/features/workflows/presentation/cubit/workflow_notifications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineRepository implements WorkflowNotificationRepository {
  @override
  bool get isOfflinePreview => false;

  @override
  Future<List<WorkflowNotification>> getNotifications(
          {bool unreadOnly = false}) async =>
      throw const ApiException(
        kind: ApiFailureKind.network,
        message: 'offline',
      );

  @override
  Future<void> markRead(String notification) async => throw const ApiException(
        kind: ApiFailureKind.network,
        message: 'offline',
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('اعلان‌های نمونه در قطعی شبکه با برچسب آفلاین نمایش داده می‌شوند',
      () async {
    final repository = PreviewWorkflowNotificationRepository(
      _OfflineRepository(),
    );
    final cubit = WorkflowNotificationsCubit(repository);
    await cubit.load();
    expect(cubit.state.status, WorkflowNotificationsStatus.ready);
    expect(cubit.state.offline, isTrue);
    expect(cubit.state.items, isNotEmpty);
    expect(cubit.state.unreadCount, cubit.state.items.length);
    await cubit.close();
  });

  test('خواندن اعلان آفلاین روی گوشی باقی می‌ماند', () async {
    final repository = PreviewWorkflowNotificationRepository(
      _OfflineRepository(),
    );
    final cubit = WorkflowNotificationsCubit(repository);
    await cubit.load();
    final item = cubit.state.items.first;
    await cubit.markRead(item);
    expect(cubit.state.items.first.isRead, isTrue);

    final another = WorkflowNotificationsCubit(
      PreviewWorkflowNotificationRepository(_OfflineRepository()),
    );
    await another.load();
    expect(
        another.state.items.firstWhere((value) => value.id == item.id).isRead,
        isTrue);
    await cubit.close();
    await another.close();
  });
}
