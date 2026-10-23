import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../domain/entities/request_models.dart';

Color _color(RequestExecution execution) => switch (execution.state) {
      'succeeded' => AsoudColors.success,
      'failed' || 'needs_review' || 'voided' => AsoudColors.danger,
      'pending' || 'not_started' => AsoudColors.warning,
      _ => AsoudColors.muted,
    };

IconData _icon(RequestExecution execution) => switch (execution.state) {
      'succeeded' => Icons.check_circle_rounded,
      'failed' || 'needs_review' => Icons.error_outline_rounded,
      'pending' => Icons.hourglass_top_rounded,
      'voided' => Icons.block_rounded,
      'not_connected' => Icons.link_off_rounded,
      _ => Icons.pending_actions_rounded,
    };

/// «عملیات اجرایی»: what was done after the approval, from `get_request.execution`.
/// Only a succeeded execution says it is done. Renders nothing when the request
/// has no execution.
class RequestExecutionCard extends StatelessWidget {
  const RequestExecutionCard({required this.execution, super.key});

  final RequestExecution execution;

  @override
  Widget build(BuildContext context) {
    if (!execution.applicable) return const SizedBox.shrink();
    final color = _color(execution);
    final rows = <String>[
      if (execution.succeeded && execution.reference.isNotEmpty)
        'شماره سند اجرا: ${execution.reference}',
      if (execution.succeeded && execution.executedByName.isNotEmpty)
        'انجام‌دهنده: ${execution.executedByName}',
      if (execution.succeeded && execution.executedOn.isNotEmpty)
        'زمان اجرا: ${formatJalaliDateTimeIso(execution.executedOn)}',
      if (execution.voided && execution.voidReason.isNotEmpty)
        'دلیل ابطال: ${execution.voidReason}',
      if (execution.voided && execution.voidByName.isNotEmpty)
        'ابطال‌کننده: ${execution.voidByName}',
      if (execution.voided && execution.voidOn.isNotEmpty)
        'زمان ابطال: ${formatJalaliDateTimeIso(execution.voidOn)}',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_icon(execution), size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text('عملیات اجرایی',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(execution.sentence,
            style: const TextStyle(fontSize: 13, height: 1.7)),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(row,
                style:
                    const TextStyle(fontSize: 12, color: AsoudColors.muted)),
          ),
        if (execution.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(execution.error,
                  style: const TextStyle(
                      fontSize: 12, color: AsoudColors.danger, height: 1.7)),
            ),
          ),
      ]),
    );
  }
}

/// «برچسب: مقدار قبلی ← مقدار جدید» lines of an edit; [labelOf] and [format]
/// give the field label and the displayed value.
List<String> requestChangeLines(
  Map<String, dynamic> before,
  Map<String, dynamic> after, {
  required String Function(String key) labelOf,
  required String Function(String key, Object? value) format,
}) =>
    [
      for (final key in {...after.keys, ...before.keys})
        '${labelOf(key)}: ${format(key, before[key])} ← ${format(key, after[key])}',
    ];
