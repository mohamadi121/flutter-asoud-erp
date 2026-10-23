import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../domain/entities/workflow_task.dart';
import 'request_returned_banner.dart' show requestActivityComment;

/// The meaning of a workflow action, used to colour and icon the timeline.
enum WorkflowActivityOutcome { approved, rejected, returned, neutral, pending }

WorkflowActivityOutcome workflowActivityOutcome(String action) =>
    switch (action.trim()) {
      'Approve' ||
      'Complete' ||
      'Condition True' ||
      'Workflow stage completed' ||
      'Workflow request approved' =>
        WorkflowActivityOutcome.approved,
      'Reject' ||
      'Condition False' ||
      'Workflow request rejected' =>
        WorkflowActivityOutcome.rejected,
      'Return' ||
      'Workflow request returned for correction' =>
        WorkflowActivityOutcome.returned,
      _ => WorkflowActivityOutcome.neutral,
    };

/// Persian label for a workflow activity, replacing the raw server action.
String workflowActivityLabel(String action) => switch (action.trim()) {
      'Complete' || 'Workflow stage completed' => 'مرحله تکمیل شد',
      'Approve' || 'Workflow request approved' => 'تأیید شد',
      'Reject' || 'Workflow request rejected' => 'رد شد',
      'Return' || 'Workflow request returned for correction' => 'برای اصلاح بازگردانده شد',
      'Condition True' => 'شرط برقرار بود',
      'Condition False' => 'شرط برقرار نبود',
      'System Action Succeeded' => 'اقدام خودکار انجام شد',
      'System Action Failed' => 'خطای اقدام خودکار',
      'Cancelled' => 'لغو شد',
      'Edited' => 'ویرایش شد',
      'Resubmitted' => 'اصلاح و ارسال مجدد',
      _ => persianWorkflowStageTitle(action),
    };

Color _outcomeColor(WorkflowActivityOutcome outcome) => switch (outcome) {
      WorkflowActivityOutcome.approved => AsoudColors.success,
      WorkflowActivityOutcome.rejected => AsoudColors.danger,
      WorkflowActivityOutcome.returned => AsoudColors.warning,
      WorkflowActivityOutcome.neutral || WorkflowActivityOutcome.pending =>
        AsoudColors.muted,
    };

IconData _outcomeIcon(WorkflowActivityOutcome outcome) => switch (outcome) {
      WorkflowActivityOutcome.approved => Icons.check_circle_rounded,
      WorkflowActivityOutcome.rejected => Icons.cancel_rounded,
      WorkflowActivityOutcome.returned => Icons.undo_rounded,
      WorkflowActivityOutcome.neutral => Icons.circle,
      WorkflowActivityOutcome.pending => Icons.schedule_rounded,
    };

/// A shared, outcome-coloured vertical timeline for workflow activities. When
/// [pending] is set a grey clock row is appended for the action still awaited.
class WorkflowActivityTimeline extends StatelessWidget {
  const WorkflowActivityTimeline({
    required this.activities,
    this.pending = false,
    this.pendingLabel = 'در انتظار اقدام شما',
    super.key,
  });

  final List<WorkflowTaskActivity> activities;
  final bool pending;
  final String pendingLabel;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty && !pending) return const SizedBox.shrink();
    final count = activities.length + (pending ? 1 : 0);
    return Column(
      children: [
        for (var i = 0; i < activities.length; i++)
          _TimelineRow(
            outcome: workflowActivityOutcome(activities[i].action),
            label: workflowActivityLabel(activities[i].action),
            actor: activities[i].actor,
            createdOn: activities[i].createdOn,
            comment: requestActivityComment(activities[i]),
            last: i == count - 1,
          ),
        if (pending)
          _TimelineRow(
            outcome: WorkflowActivityOutcome.pending,
            label: pendingLabel,
            actor: '',
            createdOn: null,
            comment: '',
            last: true,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.outcome,
    required this.label,
    required this.actor,
    required this.createdOn,
    required this.comment,
    required this.last,
  });

  final WorkflowActivityOutcome outcome;
  final String label, actor, comment;
  final DateTime? createdOn;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = _outcomeColor(outcome);
    final formattedActor = actor.contains('@')
        ? '${String.fromCharCode(0x2066)}$actor${String.fromCharCode(0x2069)}'
        : actor;
    final meta = [
      if (formattedActor.isNotEmpty) formattedActor,
      if (createdOn != null) formatDateTimeJalali(createdOn),
    ].join(' • ');
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            CircleAvatar(
              radius: 9,
              backgroundColor: color,
              child: Icon(_outcomeIcon(outcome), size: 12, color: Colors.white),
            ),
            if (!last)
              Expanded(child: Container(width: 2, color: AsoudColors.border)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: color)),
                if (meta.isNotEmpty)
                  Tooltip(
                    message: meta,
                    child: Text(meta,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                  ),
                if (comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(comment,
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
