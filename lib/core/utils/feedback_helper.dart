import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

/// Centralized utility for haptics and toast notifications.
class FeedbackHelper {
  FeedbackHelper._();

  /// Trigger a selection click haptic feedback.
  static Future<void> triggerSelection() async {
    await HapticFeedback.selectionClick();
  }

  /// Trigger a light impact haptic feedback (taps, operations).
  static Future<void> triggerLight() async {
    await HapticFeedback.lightImpact();
  }

  /// Trigger a medium impact haptic feedback (deletes, resets).
  static Future<void> triggerMedium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Trigger a vibrate pattern (errors, warnings).
  static Future<void> triggerError() async {
    await HapticFeedback.vibrate();
  }

  /// Displays an elegant, minimalist success SnackBar with haptics.
  static void showSuccess(BuildContext context, String message) {
    triggerLight();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.accentEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Displays an elegant, minimalist error SnackBar with haptics.
  static void showError(BuildContext context, String message) {
    triggerError();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
