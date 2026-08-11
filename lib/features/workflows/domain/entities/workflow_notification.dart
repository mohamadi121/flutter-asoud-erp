import 'package:equatable/equatable.dart';

class WorkflowNotification extends Equatable {
  const WorkflowNotification({
    required this.id,
    required this.title,
    this.message = '',
    this.instance = '',
    this.isRead = false,
    this.createdAt,
    this.localOnly = false,
  });

  final String id, title, message, instance;
  final bool isRead, localOnly;
  final DateTime? createdAt;

  WorkflowNotification copyWith({bool? isRead}) => WorkflowNotification(
        id: id,
        title: title,
        message: message,
        instance: instance,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        localOnly: localOnly,
      );

  @override
  List<Object?> get props =>
      [id, title, message, instance, isRead, createdAt, localOnly];
}
