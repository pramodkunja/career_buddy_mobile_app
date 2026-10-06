import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'mock_exam_colors.dart';

/// `.warning-box`/`.warning-backdrop` (`amcat_mock_test.html`) — the shared
/// container both `#warningModal` (fullscreen-exit security warning) and
/// `#exitConfirmModal` ("Exit the assessment?") use: a white, radius-14
/// centered card over a dark navy scrim, a warning icon, a danger-colored
/// heading, muted body text, and a Cancel/confirm button row. Used for
/// both the "Leave test?" (OOP Mastery / Subject Quiz) and "Exit the
/// assessment?" (AMCAT / CoCubes) confirmations — same web container, only
/// the copy differs per caller.
Future<bool> showMockExamWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Exit Test',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB80B1526),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: MockExamColors.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x1A101828), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: MockExamColors.danger, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MockExamColors.danger, fontWeight: FontWeight.w800, fontSize: 17, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MockExamColors.muted, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MockExamColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
