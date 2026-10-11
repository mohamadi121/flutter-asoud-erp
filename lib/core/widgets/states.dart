import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/asoud_colors.dart';
import '../utils/failure_message.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({required this.failure, this.onRetry, super.key});

  const ErrorState.forbidden({super.key})
      : failure = const ApiException(
            kind: ApiFailureKind.forbidden, message: 'forbidden'),
        onRetry = null;

  final Object failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final canRetry = onRetry != null && failureCanRetry(failure);
    final isForbidden = failureIsForbidden(failure);
    return _StateLayout(
      icon: _failureIcon(failure),
      color: isForbidden ? AsoudColors.danger : AsoudColors.warning,
      title: isForbidden ? 'دسترسی محدود است' : 'دریافت اطلاعات ناموفق بود',
      description: failureMessage(failure),
      action: canRetry
          ? FilledButton(onPressed: onRetry, child: const Text('تلاش دوباره'))
          : null,
    );
  }

  IconData _failureIcon(Object failure) =>
      failure is ApiException && failure.kind == ApiFailureKind.forbidden
          ? Icons.lock_outline_rounded
          : Icons.error_outline_rounded;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) => _StateLayout(
        icon: icon,
        color: AsoudColors.primary,
        title: title,
        description: description,
        action: primaryActionLabel != null && onPrimaryAction != null
            ? FilledButton(
                onPressed: onPrimaryAction, child: Text(primaryActionLabel!))
            : null,
      );
}

class ComingSoonState extends StatelessWidget {
  const ComingSoonState({
    required this.description,
    this.onBack,
    super.key,
  });

  final String description;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => _StateLayout(
        icon: Icons.construction_outlined,
        color: AsoudColors.warning,
        title: 'به‌زودی',
        description: description,
        action: OutlinedButton(
          onPressed: onBack ?? () => Navigator.maybePop(context),
          child: const Text('بازگشت'),
        ),
      );
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 13, color: AsoudColors.muted)),
              if (action != null) ...[
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 48, child: action),
              ],
            ]),
          ),
        ),
      );
}
