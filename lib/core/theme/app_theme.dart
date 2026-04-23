import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme_controller.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData lightTheme(AppThemeSettings settings) {
    final palette = AppThemeController.paletteFor(settings);
    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryTeal,
        secondary: AppColors.primaryDark,
        surface: palette.surface,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.textPrimary,
        onError: AppColors.white,
      ),
      scaffoldBackgroundColor: palette.background,
      fontFamilyFallback: const ['Inter', 'Roboto', 'Arial', 'sans-serif'],
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      dividerColor: AppColors.border,
    );
  }
}
