import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/workflow_task.dart';
import 'request_execution_card.dart' show requestChangeLines;

/// The history text of an activity: its comment, then one «برچسب: قبلی ← جدید»
/// line per changed field (`before`/`after`, for example a resubmission).
/// [labelOf] and [format] come from the form when it is loaded; otherwise the
/// server's `labels` and the stored text are used.
String requestActivityComment(
  WorkflowTaskActivity activity, {
  String? Function(String key)? labelOf,
  String Function(String key, Object? value)? format,
}) {
  final lines = requestChangeLines(
    activity.before,
    activity.after,
    labelOf: (key) =>
        labelOf?.call(key) ?? activity.labels[key] ?? 'مقدار',
    format: (key, value) {
      final text = (format?.call(key, value) ?? '${value ?? ''}').trim();
      return text.isEmpty ? '—' : text;
    },
  );
  return [
    if (activity.comment.trim().isNotEmpty) activity.comment.trim(),
    ...lines,
  ].join('\n');
}

/// «برای اصلاح بازگردانده شد» with the reviewer's reason. The correction button appears
/// only when the server says the signed-in user may edit the returned request.
class RequestReturnedBanner extends StatelessWidget {
  const RequestReturnedBanner({
    required this.data,
    required this.onCorrect,
    super.key,
  });

  final Map<String, dynamic> data;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    if (data['status_key'] != 'returned') return const SizedBox.shrink();
    final reason = '${data['return_reason'] ?? ''}'.trim();
    final canCorrect = data['can_edit'] == true;
    return Container(
      key: const ValueKey('request-returned-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AsoudColors.warning.withValues(alpha: .08),
        border: Border.all(color: AsoudColors.warning.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('برای اصلاح بازگردانده شد',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('دلیل: $reason', style: const TextStyle(fontSize: 12, height: 1.7)),
        ],
        if (canCorrect) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('request-correct-button'),
            onPressed: onCorrect,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('اصلاح درخواست'),
          ),
        ],
      ]),
    );
  }
}
