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

class WorkflowTaskDetail extends Equatable {
  const WorkflowTaskDetail({
    required this.task,
    required this.stageType,
    this.fields = const [],
    this.values = const {},
    this.activities = const [],
    this.allowReject = false,
    this.allowReturn = false,
  });
  final WorkflowTask task;
  final String stageType;
  final List<WorkflowFormFieldDefinition> fields;
  final Map<String, dynamic> values;
  final List<WorkflowTaskActivity> activities;
  final bool allowReject, allowReturn;
  @override
  List<Object> get props =>
      [task, stageType, fields, values, activities, allowReject, allowReturn];
}
