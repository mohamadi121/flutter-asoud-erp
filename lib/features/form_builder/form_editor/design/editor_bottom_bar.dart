import 'package:flutter/material.dart';

class EditorBottomBar extends StatelessWidget {
  const EditorBottomBar({
    required this.busy,
    required this.previewMode,
    required this.onTogglePreview,
    required this.onSave,
    super.key,
  });

  final bool busy;
  final bool previewMode;
  final VoidCallback onTogglePreview;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: previewMode
            ? FilledButton(
                onPressed: onTogglePreview,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'بازگشت به طراحی',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onTogglePreview,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'پیش‌نمایش',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onSave,
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          busy ? 'در حال ذخیره…' : 'ذخیره پیش‌نویس',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
