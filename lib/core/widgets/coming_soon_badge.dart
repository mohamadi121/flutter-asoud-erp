import 'package:flutter/material.dart';

import '../theme/asoud_colors.dart';

/// Small Persian «به‌زودی» badge used across dashboard and feature hubs.
class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({
    this.fontSize = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    super.key,
  });

  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'به‌زودی',
          style: TextStyle(
            fontSize: fontSize,
            color: AsoudColors.warning,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
