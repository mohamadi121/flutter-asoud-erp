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
    this.dueOn,
    this.reminderSentOn,
    this.escalatedOn,
    this.localOnly = false,
    this.followup = '',
    this.action = '',
  });

  final String id;
  final String instance;
  final String stage;
  final String title;
  final String status;
  final DateTime? assignedOn;
  final DateTime? dueOn, reminderSentOn, escalatedOn;
  final bool localOnly;

  /// Kind of the follow-up the task asks for (`confirm_receipt`), empty for an
  /// ordinary workflow task (`followup` of `list_my_workflow_tasks`).
  final String followup;
  final String action;

  @override
  List<Object?> get props => [
        id,
        instance,
        stage,
        title,
        status,
        assignedOn,
        dueOn,
        reminderSentOn,
        escalatedOn,
        localOnly,
        followup,
        action,
      ];
}

class WorkflowTaskActivity extends Equatable {
  const WorkflowTaskActivity({
    required this.actor,
    required this.action,
    this.comment = '',
    this.createdOn,
    this.stageTitle = '',
    this.actorName = '',
    this.before = const {},
    this.after = const {},
    this.labels = const {},
  });
  final String actor, action, comment, stageTitle, actorName;
  final DateTime? createdOn;

  /// Field values before and after an edit (`before`/`after` of an activity
  /// row); empty for events that changed nothing.
  final Map<String, dynamic> before, after;

  /// Field labels of the changed keys (`labels` of an activity row), so the
  /// change can be shown where the form is not loaded.
  final Map<String, String> labels;
  @override
  List<Object?> get props => [
        actor,
        action,
        comment,
        createdOn,
        stageTitle,
        actorName,
        before,
        after,
        labels
      ];
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
    this.referenceDoctype = '',
    this.referenceName = '',
    this.documentValues = const [],
    this.requestName = '',
    this.requestCompany = '',
    this.requestValues = const {},
    this.submittedForm = const {},
    this.actionSchema = const {}, this.actionForm = '', this.actionCompany = '', this.actionMode = '',
    this.requiresClaim = false, this.allowDraft = true, this.allowAddAttachments = false,
    this.documentAccess = 'Read Only',
    this.allowReassign = false, this.allowOriginalAccess = true,
    this.supplementaryForm = const {},
  });
  final String requestName, requestCompany;
  final WorkflowTask task;
  final String stageType;
  final List<WorkflowFormFieldDefinition> fields;
  final Map<String, dynamic> values;
  final List<WorkflowTaskActivity> activities;
  final bool allowReject, allowReturn;
  final bool commentRequired;
  final String activityType;
  final List<WorkflowTaskDataSection> previousData;
  final String referenceDoctype, referenceName;
  final List<WorkflowTaskDataValue> documentValues;
  final Map<String, dynamic> requestValues;
  final Map<String, dynamic> submittedForm;
  final Map<String, dynamic> actionSchema;
  final String actionForm, actionCompany, actionMode;
  final bool requiresClaim, allowDraft, allowAddAttachments;
  final String documentAccess;
  final bool allowReassign, allowOriginalAccess;

  /// The approval stage's supplementary form (contract C6): `{form, revision,
  /// title, schema, values}`. Empty when the stage has no binding.
  final Map<String, dynamic> supplementaryForm;
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
        referenceDoctype,
        referenceName,
        documentValues,
        requestName,
        requestCompany,
        requestValues,
        submittedForm,
        actionSchema, actionForm, actionCompany, actionMode, requiresClaim, allowDraft, allowAddAttachments, documentAccess,
        allowReassign, allowOriginalAccess, supplementaryForm,
      ];
}

class WorkflowInstanceSummary extends Equatable {
  const WorkflowInstanceSummary({
    required this.id,
    required this.subject,
    required this.status,
    this.workflowDefinition = '',
    this.currentStage = '',
    this.currentStageTitle = '',
    this.currentAssignees = const [],
    this.referenceDoctype = '',
    this.referenceName = '',
    this.startedOn,
    this.completedOn,
    this.localOnly = false,
    this.endOutcome = '',
  });
  final String id, subject, status, workflowDefinition;
  final String currentStage, currentStageTitle;
  final List<String> currentAssignees;
  final String referenceDoctype, referenceName;
  final DateTime? startedOn, completedOn;
  final bool localOnly;
  final String endOutcome;
  @override
  List<Object?> get props => [
        id,
        subject,
        status,
        workflowDefinition,
        currentStage,
        currentStageTitle,
        currentAssignees,
        referenceDoctype,
        referenceName,
        startedOn,
        completedOn,
        localOnly,
        endOutcome,
      ];
}

class WorkflowInstanceDetail extends Equatable {
  const WorkflowInstanceDetail(
      {required this.summary, this.activities = const [], this.canRestart = false});
  final WorkflowInstanceSummary summary;
  final List<WorkflowTaskActivity> activities;
  final bool canRestart;
  @override
  List<Object> get props => [summary, activities, canRestart];
}
