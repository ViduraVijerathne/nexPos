import 'package:flutter/material.dart';

import 'app_theme_controller.dart';

class AppColors {
  const AppColors._();

  // Brand colors aligned with the requested web palette.
  static Color get primaryTeal => AppThemeController.instance.accentColor;
  static Color get primaryDark => _shiftLightness(primaryTeal, -0.08);
  static Color get primaryDarker => _shiftLightness(primaryTeal, -0.16);
  static Color get primaryLight => _shiftLightness(primaryTeal, 0.42);

  // Neutral colors for text, surfaces, and borders.
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static Color get background => AppThemeController.instance.palette.background;
  static const Color border = Color(0xFFE2E8F0);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic feedback colors.
  static const Color success = Color(0xFF48BB78);
  static const Color warning = Color(0xFFED8936);
  static const Color error = Color(0xFFF56565);
  static const Color info = Color(0xFF4299E1);

  static Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final next = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(next).toColor();
  }
}
