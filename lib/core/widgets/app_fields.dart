import 'package:flutter/material.dart';

import '../theme/asoud_colors.dart';

/// Shared look of the unified form fields (bug list #31 / UX review §10):
/// one floating-label pattern with the required mark «*» separate from the
/// hint, 12sp helper/error text, ≥48dp touch targets and RTL-first layout.
abstract final class AppFieldStyle {
  static const helperStyle = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AsoudColors.muted,
  );
  static const errorStyle = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AsoudColors.danger,
  );
  static const contentPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 14,
  );

  /// One [InputDecoration] for text fields and select fields so both have the
  /// exact same border, always-floating label and message style. The required
  /// mark is appended to [label] only when [required] and not already there;
  /// it never lands inside the hint text.
  static InputDecoration decoration({
    required String label,
    bool required = false,
    String? hint,
    String? helperText,
    String? errorText,
    bool enabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
  }) {
    final mark = required && !label.endsWith(' *') ? ' *' : '';
    return InputDecoration(
      labelText: '$label$mark',
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AsoudColors.muted),
      helperText: helperText,
      helperStyle: helperStyle,
      errorText: errorText,
      errorStyle: errorStyle,
      errorMaxLines: 3,
      enabled: enabled,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      counterText: counterText,
      filled: true,
      fillColor: AsoudColors.surface,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AsoudColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AsoudColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AsoudColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AsoudColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AsoudColors.danger, width: 1.5),
      ),
    );
  }
}

/// One text box of the unified form language: permanent floating label, the
/// required mark separate from the hint, 12sp helper/error text and a ≥48dp
/// touch target. Pass [ltr] for emails, URLs and codes so the text and its
/// caret run left-to-right inside the RTL form.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.required = false,
    this.ltr = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.counterText,
    this.counterBuilder,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint, helperText, errorText;
  final FormFieldValidator<String>? validator;
  final bool required, ltr, readOnly, enabled, obscureText;
  final int maxLines;
  final int? maxLength;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? counterText;
  final InputCounterWidgetBuilder? counterBuilder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;
  final Widget? prefixIcon, suffixIcon;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        validator: validator,
        forceErrorText: errorText,
        enabled: enabled,
        readOnly: readOnly,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textDirection: ltr ? TextDirection.ltr : null,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onTap: onTap,
        autofocus: autofocus,
        buildCounter: counterBuilder,
        decoration: AppFieldStyle.decoration(
          label: label,
          required: required,
          hint: hint,
          helperText: helperText,
          errorText: errorText,
          enabled: enabled,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          counterText: counterText,
        ),
      );
}

/// A tappable value box in the same visual language as [AppTextField]; the
/// ⌄ arrow sits on the trailing (left) edge for RTL. [onPick] opens whatever
/// picker the caller already has (a bottom sheet or a dropdown); the returned
/// value is committed through [onChanged]. [value] is the external source of
/// truth shown on the field, [displayValue] substitutes the human label.
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    this.value,
    this.displayValue,
    this.hint,
    this.helperText,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.onPick,
    this.onChanged,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.prefixIcon,
    this.suffixIcon,
  });

  final String label;
  final String? value, displayValue, hint, helperText, errorText;
  final bool required, enabled;

  /// Opens the existing picker and resolves to the chosen value (null = kept).
  final Future<String?> Function()? onPick;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final Widget? prefixIcon, suffixIcon;

  @override
  Widget build(BuildContext context) => FormField<String>(
        initialValue: value ?? '',
        validator: validator,
        autovalidateMode: autovalidateMode,
        builder: (field) {
          final empty = (value ?? '').isEmpty;
          return InkWell(
            onTap: enabled ? () => _pick(field) : null,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: empty,
              decoration: AppFieldStyle.decoration(
                label: label,
                required: required,
                hint: hint,
                helperText: helperText,
                errorText: field.errorText ?? errorText,
                enabled: enabled,
                prefixIcon: prefixIcon,
                suffixIcon: suffixIcon ??
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AsoudColors.muted,
                      size: 24,
                    ),
              ),
              child: Text(
                empty ? (hint ?? '') : (displayValue ?? value!),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: empty ? AsoudColors.muted : AsoudColors.text,
                ),
              ),
            ),
          );
        },
      );

  Future<void> _pick(FormFieldState<String> field) async {
    final picked = await onPick?.call();
    if (picked == null) return;
    field.didChange(picked);
    onChanged?.call(picked);
  }
}

/// A list tile row with the switch on the trailing edge and the state written
/// out («روشن»/«خاموش») so it is never colour-only. The whole ≥48dp row
/// toggles the switch.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.value = false,
    this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onChanged != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        toggled: value,
        enabled: active,
        child: InkWell(
          onTap: active ? () => onChanged?.call(!value) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AsoudColors.surface,
              border: Border.all(color: AsoudColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? AsoudColors.text : AsoudColors.muted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: AsoudColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value ? 'روشن' : 'خاموش',
                  key: const ValueKey('app-switch-state'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: value ? AsoudColors.success : AsoudColors.muted,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: value,
                  onChanged: active ? onChanged : null,
                  activeTrackColor: AsoudColors.success,
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFC9D1DE),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a selection sheet.
class AppOption {
  const AppOption(this.value, this.label, {this.icon, this.iconColor});
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

/// The standard bottom sheet used by [AppSelectField]; returns the picked
/// [AppOption.value] or null when the sheet is dismissed. Callers pass the
/// existing pickers of their forms through [AppSelectField.onPick].
Future<String?> showAppOptionSheet(
  BuildContext context, {
  required String title,
  required List<AppOption> options,
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          for (final option in options)
            ListTile(
              key: ValueKey('option-${option.value}'),
              leading: option.icon == null
                  ? null
                  : Icon(
                      option.icon,
                      color: option.iconColor ?? AsoudColors.primary,
                      size: 22,
                    ),
              title: Text(option.label),
              trailing: option.value == current
                  ? const Icon(
                      Icons.check_rounded,
                      color: AsoudColors.primary,
                      size: 22,
                    )
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => Navigator.pop(context, option.value),
            ),
        ],
      ),
    ),
  );
}
