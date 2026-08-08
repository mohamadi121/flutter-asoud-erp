import 'package:equatable/equatable.dart';
import 'workflow_definition.dart';

class WorkflowTask extends Equatable {
  const WorkflowTask({
    required this.id,
    required this.instance,
    required this.stage,
    required this.title,
    required this.status,
    this.assignedOn,
    this.localOnly = false,
  });

  final String id;
  final String instance;
  final String stage;
  final String title;
  final String status;
  final DateTime? assignedOn;
  final bool localOnly;

  @override
  List<Object?> get props =>
      [id, instance, stage, title, status, assignedOn, localOnly];
}

class WorkflowTaskActivity extends Equatable {
  const WorkflowTaskActivity({
    required this.actor,
    required this.action,
    this.comment = '',
    this.createdOn,
  });
  final String actor, action, comment;
  final DateTime? createdOn;
  @override
  List<Object?> get props => [actor, action, comment, createdOn];
}

class WorkflowTaskDataValue extends Equatable {
  const WorkflowTaskDataValue({
    required this.key,
    required this.label,
    required this.value,
  });
  final String key, label;
  final dynamic value;
  @override
  List<Object?> get props => [key, label, value];
}

class WorkflowTaskDataSection extends Equatable {
  const WorkflowTaskDataSection({
    required this.title,
    required this.values,
  });
  final String title;
  final List<WorkflowTaskDataValue> values;
  @override
  List<Object> get props => [title, values];
}

class WorkflowTaskDetail extends Equatable {
  const WorkflowTaskDetail({
    required this.task,
    required this.stageType,
    this.fields = const [],
    this.values = const {},
    this.activities = const [],
    this.allowReject = false,
    this.allowReturn = false,
    this.commentRequired = false,
    this.activityType = '',
    this.previousData = const [],
  });
  final WorkflowTask task;
  final String stageType;
  final List<WorkflowFormFieldDefinition> fields;
  final Map<String, dynamic> values;
  final List<WorkflowTaskActivity> activities;
  final bool allowReject, allowReturn;
  final bool commentRequired;
  final String activityType;
  final List<WorkflowTaskDataSection> previousData;
  @override
  List<Object> get props => [
        task,
        stageType,
        fields,
        values,
        activities,
        allowReject,
        allowReturn,
        commentRequired,
        activityType,
        previousData,
      ];
}
