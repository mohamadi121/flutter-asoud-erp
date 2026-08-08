import 'package:flutter/material.dart';

import '../theme/asoud_colors.dart';

class AsoudHeader extends StatelessWidget implements PreferredSizeWidget {
  const AsoudHeader(
      {required this.title, this.subtitle, this.action, super.key});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 76 : 94);

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            if (Navigator.of(context).canPop())
              _HeaderButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => Navigator.of(context).pop())
            else
              const SizedBox(width: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.muted)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 40, child: action),
          ]),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              border: Border.all(color: AsoudColors.border),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20),
        ),
      );
}

class AsoudIconBox extends StatelessWidget {
  const AsoudIconBox(
      {required this.icon, required this.color, this.size = 40, super.key});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: color, size: size * .5),
      );
}

class AsoudBottomActions extends StatelessWidget {
  const AsoudBottomActions(
      {required this.primaryLabel,
      required this.onPrimary,
      this.secondaryLabel,
      this.onSecondary,
      super.key});
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AsoudColors.border))),
          child: Row(children: [
            if (secondaryLabel != null) ...[
              Expanded(
                  flex: secondaryLabel == null ? 0 : 1,
                  child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: AsoudColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(secondaryLabel!))),
              const SizedBox(width: 10),
            ],
            Expanded(
                flex: secondaryLabel == null ? 1 : 2,
                child: FilledButton(
                    onPressed: onPrimary,
                    child: onPrimary == null && primaryLabel.contains('در حال')
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(primaryLabel))),
          ]),
        ),
      );
}

class AsoudSectionTitle extends StatelessWidget {
  const AsoudSectionTitle({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
        ]),
      );
}

class AsoudSegmentedOption<T> {
  const AsoudSegmentedOption(
      {required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class AsoudOfflinePreviewBanner extends StatelessWidget {
  const AsoudOfflinePreviewBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .09),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.cloud_off_rounded, color: AsoudColors.warning, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'حالت پیش‌نمایش آفلاین؛ اطلاعات فقط موقت است و در ERPNext ذخیره نمی‌شود.',
              style: TextStyle(fontSize: 10, height: 1.6),
            ),
          ),
        ]),
      );
}

class AsoudSegmentedControl<T> extends StatelessWidget {
  const AsoudSegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });
  final T value;
  final List<AsoudSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          for (final option in options)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(option.value),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? AsoudColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.icon != null) ...[
                        Icon(option.icon,
                            size: 18,
                            color: option.value == value
                                ? Colors.white
                                : AsoudColors.text),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(option.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: option.value == value
                                  ? Colors.white
                                  : AsoudColors.text,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      );
}
