import 'package:shared_preferences/shared_preferences.dart';

class PosTaxSettings {
  const PosTaxSettings({required this.isTaxEnabled, required this.taxPercent});

  final bool isTaxEnabled;
  final double taxPercent;

  double get taxRate => taxPercent / 100;
}

class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const String _posTaxEnabledKey = 'settings.pos_tax_enabled';
  static const String _posTaxPercentKey = 'settings.pos_tax_percent';

  Future<PosTaxSettings> loadPosTaxSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return PosTaxSettings(
      isTaxEnabled: prefs.getBool(_posTaxEnabledKey) ?? false,
      taxPercent: prefs.getDouble(_posTaxPercentKey) ?? 10,
    );
  }

  Future<void> savePosTaxSettings({
    required bool isTaxEnabled,
    required double taxPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_posTaxEnabledKey, isTaxEnabled);
    await prefs.setDouble(_posTaxPercentKey, taxPercent);
  }
}
