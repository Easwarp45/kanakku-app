import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0E27);
  static const Color bgSecondary = Color(0xFF131829);
  static const Color bgTertiary = Color(0xFF1A1F3A);
  static const Color bgElevated = Color(0xFF242D4A);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A8C0);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF4B5563);

  // Accent Colors
  static const Color accentCyan = Color(0xFF00D9FF);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentAmber = Color(0xFFFBBF24);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Semantic
  static const Color success = accentEmerald;
  static const Color error = accentRose;
  static const Color warning = accentAmber;
  static const Color info = accentBlue;

  // Borders & Overlays
  static const Color border = Color(0x14FFFFFF); // 8% white
  static const Color borderSubtle = Color(0x0AFFFFFF); // 4% white
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayDark = Color(0xCC000000); // 80% black
}
