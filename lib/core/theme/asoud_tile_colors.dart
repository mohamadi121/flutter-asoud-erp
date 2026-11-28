import 'package:flutter/material.dart';

import 'asoud_colors.dart';

/// One calm colour for every navigation tile; colour is reserved for status
/// (today, holiday, overdue, selected, disabled).
abstract final class AsoudTileColors {
  /// Icon and accent colour shared by all module and hub tiles.
  static const base = AsoudColors.primary;
  static const disabled = AsoudColors.muted;

  /// Neutral surface of a calendar day without any status.
  static const daySurface = AsoudColors.background;

  static Color dayBackground({
    required bool selected,
    required bool overdue,
    required bool holiday,
    required bool today,
  }) {
    if (selected) return AsoudColors.primary;
    if (overdue) return AsoudColors.dangerSurface;
    if (holiday) return AsoudColors.warningSurface;
    if (today) return AsoudColors.primary.withValues(alpha: .08);
    return daySurface;
  }

  static Color dayForeground({required bool selected}) =>
      selected ? Colors.white : AsoudColors.text;
}
