import 'package:equatable/equatable.dart';

class WorkflowTask extends Equatable {
  const WorkflowTask({
    required this.id,
    required this.instance,
    required this.stage,
    required this.title,
    required this.status,
    this.assignedOn,
  });

  final String id;
  final String instance;
  final String stage;
  final String title;
  final String status;
  final DateTime? assignedOn;

  @override
  List<Object?> get props => [id, instance, stage, title, status, assignedOn];
}
