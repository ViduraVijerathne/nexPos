import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeStyle {
  defaultLight('Default Light'),
  skyLight('Sky Light'),
  sageLight('Sage Light'),
  sandLight('Sand Light');

  const AppThemeStyle(this.label);

  final String label;
}

class AppThemeSettings {
  const AppThemeSettings({required this.style, required this.accentColorValue});

  final AppThemeStyle style;
  final int accentColorValue;

  Color get accentColor => Color(accentColorValue);

  AppThemeSettings copyWith({AppThemeStyle? style, int? accentColorValue}) {
    return AppThemeSettings(
      style: style ?? this.style,
      accentColorValue: accentColorValue ?? this.accentColorValue,
    );
  }
}

class AppThemePalette {
  const AppThemePalette({
    required this.background,
    required this.surface,
    required this.sidebarBackground,
    required this.sectionBannerTint,
  });

  final Color background;
  final Color surface;
  final Color sidebarBackground;
  final Color sectionBannerTint;
}

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const _styleKey = 'settings.app_theme_style';
  static const _accentKey = 'settings.app_theme_accent';

  static const AppThemeSettings defaultSettings = AppThemeSettings(
    style: AppThemeStyle.defaultLight,
    accentColorValue: 0xFF38B2AC,
  );

  static const List<Color> accentPresets = [
    Color(0xFF38B2AC),
    Color(0xFF4299E1),
    Color(0xFF48BB78),
    Color(0xFFED8936),
    Color(0xFFEC4899),
    Color(0xFF7C3AED),
  ];

  AppThemeSettings _settings = defaultSettings;

  AppThemeSettings get settings => _settings;
  Color get accentColor => _settings.accentColor;

  AppThemePalette get palette => switch (_settings.style) {
    AppThemeStyle.defaultLight => const AppThemePalette(
      background: Color(0xFFF7FAFC),
      surface: Color(0xFFFFFFFF),
      sidebarBackground: Color(0xFFFFFFFF),
      sectionBannerTint: Color(0xFFF6F9FC),
    ),
    AppThemeStyle.skyLight => const AppThemePalette(
      background: Color(0xFFF4F8FF),
      surface: Color(0xFFFFFFFF),
      sidebarBackground: Color(0xFFFDFEFF),
      sectionBannerTint: Color(0xFFF3F8FF),
    ),
    AppThemeStyle.sageLight => const AppThemePalette(
      background: Color(0xFFF5FBF7),
      surface: Color(0xFFFFFFFF),
      sidebarBackground: Color(0xFFFCFEFD),
      sectionBannerTint: Color(0xFFF3FBF5),
    ),
    AppThemeStyle.sandLight => const AppThemePalette(
      background: Color(0xFFFBF8F3),
      surface: Color(0xFFFFFFFF),
      sidebarBackground: Color(0xFFFFFEFC),
      sectionBannerTint: Color(0xFFFCF7EF),
    ),
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStyle = prefs.getString(_styleKey);
    final style = AppThemeStyle.values.firstWhere(
      (item) => item.name == rawStyle,
      orElse: () => defaultSettings.style,
    );
    _settings = AppThemeSettings(
      style: style,
      accentColorValue:
          prefs.getInt(_accentKey) ?? defaultSettings.accentColorValue,
    );
    notifyListeners();
  }

  Future<void> updateTheme({AppThemeStyle? style, Color? accentColor}) async {
    final nextSettings = _settings.copyWith(
      style: style,
      accentColorValue: accentColor?.value,
    );
    _settings = nextSettings;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, nextSettings.style.name);
    await prefs.setInt(_accentKey, nextSettings.accentColorValue);
  }
}
