import 'package:flutter/material.dart';

enum UnsavedChangesAction {
  cancel,
  saveAndExit,
  discardAndExit,
}

Future<UnsavedChangesAction?> showUnsavedChangesDialog(
  BuildContext context,
) =>
    showDialog<UnsavedChangesAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEAB308),
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تغییرات ذخیره‌نشده',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'تغییراتی در فرم ایجاد کرده‌اید که هنوز ذخیره نشده‌اند. مایلید چگونه ادامه دهید؟',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, UnsavedChangesAction.cancel),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(80, 40),
              ),
              child: const Text('ادامه طراحی'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogCtx,
                UnsavedChangesAction.discardAndExit,
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('خروج بدون ذخیره'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogCtx,
                UnsavedChangesAction.saveAndExit,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('ذخیره و خروج'),
            ),
          ],
        ),
      ),
    );
