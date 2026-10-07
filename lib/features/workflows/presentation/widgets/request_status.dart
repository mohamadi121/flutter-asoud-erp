import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/request_models.dart';

/// The chip color of a server status (§5).
Color requestStatusColor(RequestStatusKey key) => switch (key) {
      RequestStatusKey.submitted => AsoudColors.primary,
      RequestStatusKey.inReview => AsoudColors.warning,
      RequestStatusKey.returned => AsoudColors.warning,
      RequestStatusKey.failed => AsoudColors.danger,
      RequestStatusKey.approved => AsoudColors.success,
      RequestStatusKey.rejected => AsoudColors.danger,
      RequestStatusKey.cancelled => AsoudColors.muted,
      RequestStatusKey.draft => AsoudColors.warning,
    };

/// Label and color of a request's status for chips and print. Client-only
/// states come first («ذخیره روی گوشی», «در انتظار همگام‌سازی»); then
/// `status_key` / `status_label`; rows without a `status_key` use the legacy
/// mapping of the instance `status`.
(String, Color) requestStatus(Map<String, dynamic> data) {
  final key = '${data['status_key'] ?? ''}';
  if (data['local_preview'] == true) {
    return ('ذخیره روی گوشی', AsoudColors.primary);
  }
  if (data['pending_sync'] == true) {
    return key == 'failed'
        ? ('نیازمند بررسی', AsoudColors.danger)
        : ('در انتظار همگام‌سازی', AsoudColors.primary);
  }
  final display = '${data['display_status'] ?? ''}';
  if (RequestStatusKey.isKnown(key)) {
    final status = RequestStatusKey.fromServer(key);
    final label = '${data['status_label'] ?? ''}';
    final custom = label.isNotEmpty && label != status.label;
    return (
      label.isNotEmpty ? label : status.label,
      custom &&
              (status == RequestStatusKey.submitted ||
                  status == RequestStatusKey.inReview)
          ? AsoudColors.primary
          : requestStatusColor(status)
    );
  }
  final status = '${data['status'] ?? ''}';
  if (status == 'Draft') {
    return (display.isNotEmpty ? display : 'پیش‌نویس', AsoudColors.warning);
  }
  final base = switch (status) {
    'Completed' => ('تکمیل شده', AsoudColors.success),
    'Rejected' => ('رد شده', AsoudColors.danger),
    'Cancelled' => ('لغو شده', AsoudColors.muted),
    'Failed' => ('نیازمند بررسی', AsoudColors.danger),
    _ => ('در انتظار تأیید', AsoudColors.warning),
  };
  return display.isNotEmpty && status == 'Running'
      ? (display, AsoudColors.primary)
      : base;
}

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.data, {super.key});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final (label, color) = requestStatus(data);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// The extra chip for the native ERP document created after approval
/// (`native.status`); nothing for a request without one or a skipped one.
class RequestNativeChip extends StatelessWidget {
  const RequestNativeChip(this.native, {super.key});
  final RequestNative native;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (native.status) {
      'Created' => ('سند ERP ایجاد شد', AsoudColors.success),
      'Pending' => ('در انتظار ایجاد سند ERP', AsoudColors.primary),
      'Failed' => ('ایجاد سند ERP ناموفق بود', AsoudColors.danger),
      _ => ('', AsoudColors.muted),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// The text to show for a failed action: the message of an [ApiException]
/// (the server's own text for a rejected request) or of a [StateError] (the
/// repository's explanation, e.g. a demo request cannot be changed);
/// [fallback] for anything else.
String requestErrorMessage(Object error, String fallback) {
  final message = switch (error) {
    ApiException(:final message) => message,
    StateError(:final message) => message,
    _ => '',
  };
  return message.trim().isEmpty ? fallback : message;
}
