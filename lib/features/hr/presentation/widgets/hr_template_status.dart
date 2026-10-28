import 'package:flutter/material.dart';

class HrTemplateStatus extends StatelessWidget {
  const HrTemplateStatus({required this.error, required this.onRetry,
    required this.child, super.key});

  final String? error;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(children: [
    if (error != null) Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text('دریافت قالب انجام نشد. $error'),
        TextButton(onPressed: onRetry, child: const Text('دریافت دوباره قالب')),
      ]),
    ),
    Expanded(child: child),
  ]);
}
