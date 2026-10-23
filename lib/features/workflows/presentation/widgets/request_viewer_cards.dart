import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../pages/workflow_task_detail_page.dart';

/// Persian sentence for the requester's own view, from the request status key.
String requesterStatusMessage(String statusKey) => switch (statusKey) {
      'returned' => 'درخواست برای اصلاح به شما بازگردانده شده است.',
      'approved' => 'درخواست شما تأیید شده است.',
      'rejected' => 'درخواست شما رد شده است.',
      'cancelled' => 'این درخواست لغو شده است.',
      'failed' => 'پردازش درخواست شما با خطا روبه‌رو شد.',
      'draft' => 'این درخواست هنوز ارسال نشده است.',
      _ => 'درخواست شما در انتظار بررسی مسئول مربوط است.',
    };

/// «وضعیت درخواست من» for the requester and «اقدام» for the user holding an open task.
/// Both come from `viewer` in `get_request`; nothing is guessed on the device.
class RequestViewerCards extends StatelessWidget {
  const RequestViewerCards({
    required this.data,
    required this.tasks,
    required this.onDecided,
    super.key,
  });

  final Map<String, dynamic> data;
  final WorkflowTaskRepository? tasks;
  final VoidCallback onDecided;

  @override
  Widget build(BuildContext context) {
    final viewer = data['viewer'];
    if (viewer is! Map) return const SizedBox.shrink();
    final task = viewer['open_task'] is Map
        ? Map<String, dynamic>.from(viewer['open_task'] as Map)
        : null;
    return Column(children: [
      if (viewer['is_requester'] == true)
        _card(
            'وضعیت درخواست من',
            viewer['self_approval_blocked'] == true
                ? 'تأیید درخواست خودتان مجاز نیست.'
                : requesterStatusMessage('${data['status_key'] ?? ''}'),
            AsoudColors.primary),
      if (task != null && tasks != null)
        _ActionCard(task: task, tasks: tasks!, onDecided: onDecided),
    ]);
  }
}

Widget _card(String title, String message, Color color, [Widget? child]) =>
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(message, style: const TextStyle(fontSize: 13)),
        if (child != null) ...[const SizedBox(height: 10), child],
      ]),
    );

class _ActionCard extends StatefulWidget {
  const _ActionCard(
      {required this.task, required this.tasks, required this.onDecided});
  final Map<String, dynamic> task;
  final WorkflowTaskRepository tasks;
  final VoidCallback onDecided;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _busy = false;

  Future<void> _decide(String action, String label) async {
    if (_busy) return;
    final required = action == 'Return' || action == 'Reject' ||
        widget.task['comment_required'] == true;
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReasonSheet(title: label, required: required),
    );
    if (comment == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.tasks.completeTask(
          task: '${widget.task['name']}',
          action: action,
          comment: comment.isEmpty ? null : comment);
      if (!mounted) return;
      widget.onDecided();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final approve = '${task['approve_action']}';
    return _card(
      'اقدام',
      'این درخواست در مرحله «${task['stage_title']}» منتظر تصمیم شماست.',
      AsoudColors.purple,
      task['has_form'] == true
          ? FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RepositoryProvider<WorkflowTaskRepository>.value(
                        value: widget.tasks,
                        child: WorkflowTaskDetailPage(task: '${task['name']}'))));
                if (mounted) widget.onDecided();
              },
              child: const Text('ثبت اطلاعات و تصمیم'))
          : Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AsoudColors.success),
                  onPressed: _busy ? null : () => _decide(approve, 'تأیید'),
                  child: const Text('تأیید')),
              if (task['allow_return'] == true)
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AsoudColors.warning),
                    onPressed:
                        _busy ? null : () => _decide('Return', 'بازگرداندن'),
                    child: const Text('بازگرداندن')),
              if (task['allow_reject'] == true)
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AsoudColors.danger),
                    onPressed: _busy ? null : () => _decide('Reject', 'رد'),
                    child: const Text('رد')),
            ]),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.required});
  final String title;
  final bool required;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: widget.required ? 'دلیل (الزامی)' : 'توضیح',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.required && _reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, _reason.text.trim()),
              child: Text(widget.title),
            ),
          ),
        ]),
      );
}
