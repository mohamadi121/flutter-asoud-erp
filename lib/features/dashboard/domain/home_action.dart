/// What a home button does for one section (spec section 28).
enum HomeActionKind {
  /// Ready and permitted: open the section's main page.
  open,

  /// Active but not configured: open that section's own setup page.
  openSetup,

  /// Module off and the user may enable it: show status plus «فعال‌سازی».
  offerEnable,

  /// Module off and the user may not enable it: show the status only.
  showDisabled,

  /// No permission: nothing runs.
  denied,
}

enum ModuleState { ready, needsSetup, disabled }

/// Pure rule behind every home button. A missing permission always wins, so a
/// user without access never reaches a setup page or an enable action.
HomeActionKind resolveHomeAction({
  required ModuleState state,
  required bool canUse,
  bool canEnable = false,
}) {
  if (state == ModuleState.disabled) {
    return canEnable ? HomeActionKind.offerEnable : HomeActionKind.showDisabled;
  }
  if (!canUse) return HomeActionKind.denied;
  return state == ModuleState.ready
      ? HomeActionKind.open
      : HomeActionKind.openSetup;
}
