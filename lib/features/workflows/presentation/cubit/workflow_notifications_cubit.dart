import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workflow_notification.dart';
import '../../domain/repositories/workflow_notification_repository.dart';

enum WorkflowNotificationsStatus { loading, ready, failure }

class WorkflowNotificationsState extends Equatable {
  const WorkflowNotificationsState({
    this.status = WorkflowNotificationsStatus.loading,
    this.items = const [],
    this.unreadOnly = false,
    this.offline = false,
    this.message,
  });
  final WorkflowNotificationsStatus status;
  final List<WorkflowNotification> items;
  final bool unreadOnly, offline;
  final String? message;
  int get unreadCount => items.where((item) => !item.isRead).length;
  @override
  List<Object?> get props => [status, items, unreadOnly, offline, message];
}

class WorkflowNotificationsCubit extends Cubit<WorkflowNotificationsState> {
  WorkflowNotificationsCubit(this._repository)
      : super(const WorkflowNotificationsState());
  final WorkflowNotificationRepository _repository;

  Future<void> load({bool? unreadOnly}) async {
    final filter = unreadOnly ?? state.unreadOnly;
    emit(WorkflowNotificationsState(unreadOnly: filter));
    try {
      final items = await _repository.getNotifications(unreadOnly: filter);
      emit(WorkflowNotificationsState(
        status: WorkflowNotificationsStatus.ready,
        items: items,
        unreadOnly: filter,
        offline: _repository.isOfflinePreview,
      ));
    } catch (error) {
      emit(WorkflowNotificationsState(
        status: WorkflowNotificationsStatus.failure,
        unreadOnly: filter,
        message: error.toString(),
      ));
    }
  }

  Future<void> markRead(WorkflowNotification item) async {
    if (item.isRead) return;
    await _repository.markRead(item.id);
    emit(WorkflowNotificationsState(
      status: WorkflowNotificationsStatus.ready,
      items: state.items
          .map((current) =>
              current.id == item.id ? current.copyWith(isRead: true) : current)
          .where((current) => !state.unreadOnly || !current.isRead)
          .toList(growable: false),
      unreadOnly: state.unreadOnly,
      offline: state.offline,
    ));
  }
}
