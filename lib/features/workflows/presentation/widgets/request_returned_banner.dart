import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';

/// The history comment of an activity. A resubmission stores its changed fields as JSON;
/// they are shown as «برچسب: قبلی ← جدید» lines, every other comment is shown as it is.
String requestActivityComment(String action, String comment) {
  if (action != 'Resubmitted') return comment;
  try {
    final decoded = jsonDecode(comment);
    final changes = decoded is Map ? decoded['changes'] : null;
    if (changes is! List) return '';
    return [
      for (final change in changes)
        if (change is Map)
          '${change['label'] ?? change['key']}: '
              '${_shown(change['before'])} ← ${_shown(change['after'])}',
    ].join('\n');
  } catch (_) {
    return '';
  }
}

String _shown(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? '—' : text;
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
