import 'package:flutter/material.dart';

class DesignerHeader extends StatelessWidget implements PreferredSizeWidget {
  const DesignerHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.previewMode = false,
    this.onTogglePreview,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool previewMode;
  final VoidCallback? onTogglePreview;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 58 : 66);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button on the right (RTL start)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  iconSize: 22,
                  tooltip: 'بازگشت',
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF334155),
                  ),
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Preview toggle button on the left (RTL end)
              SizedBox(
                width: 48,
                height: 48,
                child: onTogglePreview != null
                    ? IconButton(
                        iconSize: 22,
                        tooltip:
                            previewMode ? 'بازگشت به طراحی' : 'پیش‌نمایش فرم',
                        icon: Icon(
                          previewMode
                              ? Icons.edit_note_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF1E88E5),
                        ),
                        onPressed: onTogglePreview,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
