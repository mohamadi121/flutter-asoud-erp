import 'package:flutter/material.dart';

class SheetBottomButtons extends StatelessWidget {
  const SheetBottomButtons({
    required this.isEditing,
    required this.isPreviewing,
    required this.onPrimary,
    required this.onPreviewToggle,
    required this.onCancel,
    this.primaryBusy = false,
    this.isColumn = false,
    super.key,
  });

  final bool isEditing;
  final bool isPreviewing;
  final VoidCallback onPrimary;
  final VoidCallback onPreviewToggle;
  final VoidCallback onCancel;
  final bool primaryBusy;
  final bool isColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Primary Button
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: primaryBusy ? null : onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1876D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: primaryBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          isColumn
                              ? (isEditing ? 'ذخیره تغییرات مشخصه' : 'تأیید و افزودن مشخصه')
                              : (isEditing ? 'ذخیره تغییرات' : 'تأیید و افزودن'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Row 2: Preview and Cancel buttons
          Row(
            children: [
              // Preview (پیش‌نمایش) - Right in RTL
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: onPreviewToggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F2FF),
                      foregroundColor: const Color(0xFF1876D2),
                      side: const BorderSide(color: Color(0xFFBCD8FF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPreviewing ? Icons.edit_note : Icons.visibility_outlined,
                          size: 18,
                          color: const Color(0xFF1876D2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPreviewing ? 'بازگشت به تنظیمات' : 'پیش‌نمایش',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1876D2),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Cancel (انصراف) - Left in RTL
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B6478),
                      side: const BorderSide(color: Color(0xFFE2E8F2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close, size: 18, color: Color(0xFF5B6478)),
                        const SizedBox(width: 6),
                        const Text(
                          'انصراف',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B6478),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
