import 'package:shared_preferences/shared_preferences.dart';

class PosTaxSettings {
  const PosTaxSettings({required this.isTaxEnabled, required this.taxPercent});

  final bool isTaxEnabled;
  final double taxPercent;

  double get taxRate => taxPercent / 100;
}

class PosCustomerSettings {
  const PosCustomerSettings({required this.createCustomerOnlyContact});

  final bool createCustomerOnlyContact;
}

enum InvoicePaperSize {
  thermal80mm('80mm Thermal Printer'),
  a4('A4 Size');

  const InvoicePaperSize(this.label);

  final String label;
}

enum InvoiceLanguage {
  english('English'),
  sinhala('සිංහල');

  const InvoiceLanguage(this.label);

  final String label;
}

class InvoiceLayoutSettings {
  const InvoiceLayoutSettings({
    required this.paperSize,
    required this.language,
    required this.englishFontFamily,
    required this.sinhalaFontFamily,
    required this.marginTop,
    required this.marginRight,
    required this.marginBottom,
    required this.marginLeft,
  });

  final InvoicePaperSize paperSize;
  final InvoiceLanguage language;
  final String englishFontFamily;
  final String sinhalaFontFamily;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;

  static const InvoiceLayoutSettings defaults = InvoiceLayoutSettings(
    paperSize: InvoicePaperSize.thermal80mm,
    language: InvoiceLanguage.english,
    englishFontFamily: '',
    sinhalaFontFamily: 'Noto Sans Sinhala',
    marginTop: 16,
    marginRight: 14,
    marginBottom: 16,
    marginLeft: 14,
  );
}

class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const String _posTaxEnabledKey = 'settings.pos_tax_enabled';
  static const String _posTaxPercentKey = 'settings.pos_tax_percent';
  static const String _posCustomerOnlyContactKey =
      'settings.pos_customer_only_contact';
  static const String _invoicePaperSizeKey = 'settings.invoice_paper_size';
  static const String _invoiceLanguageKey = 'settings.invoice_language';
  static const String _invoiceEnglishFontKey = 'settings.invoice_english_font';
  static const String _invoiceSinhalaFontKey = 'settings.invoice_sinhala_font';
  static const String _invoiceMarginTopKey = 'settings.invoice_margin_top';
  static const String _invoiceMarginRightKey = 'settings.invoice_margin_right';
  static const String _invoiceMarginBottomKey =
      'settings.invoice_margin_bottom';
  static const String _invoiceMarginLeftKey = 'settings.invoice_margin_left';

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

  Future<PosCustomerSettings> loadPosCustomerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return PosCustomerSettings(
      createCustomerOnlyContact:
          prefs.getBool(_posCustomerOnlyContactKey) ?? false,
    );
  }

  Future<void> savePosCustomerSettings({
    required bool createCustomerOnlyContact,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_posCustomerOnlyContactKey, createCustomerOnlyContact);
  }

  Future<InvoiceLayoutSettings> loadInvoiceLayoutSettings() async {
    final prefs = await SharedPreferences.getInstance();

    InvoicePaperSize readPaperSize(String? raw) {
      return InvoicePaperSize.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => InvoiceLayoutSettings.defaults.paperSize,
      );
    }

    InvoiceLanguage readLanguage(String? raw) {
      return InvoiceLanguage.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => InvoiceLayoutSettings.defaults.language,
      );
    }

    return InvoiceLayoutSettings(
      paperSize: readPaperSize(prefs.getString(_invoicePaperSizeKey)),
      language: readLanguage(prefs.getString(_invoiceLanguageKey)),
      englishFontFamily:
          prefs.getString(_invoiceEnglishFontKey) ??
          InvoiceLayoutSettings.defaults.englishFontFamily,
      sinhalaFontFamily:
          prefs.getString(_invoiceSinhalaFontKey) ??
          InvoiceLayoutSettings.defaults.sinhalaFontFamily,
      marginTop:
          prefs.getDouble(_invoiceMarginTopKey) ??
          InvoiceLayoutSettings.defaults.marginTop,
      marginRight:
          prefs.getDouble(_invoiceMarginRightKey) ??
          InvoiceLayoutSettings.defaults.marginRight,
      marginBottom:
          prefs.getDouble(_invoiceMarginBottomKey) ??
          InvoiceLayoutSettings.defaults.marginBottom,
      marginLeft:
          prefs.getDouble(_invoiceMarginLeftKey) ??
          InvoiceLayoutSettings.defaults.marginLeft,
    );
  }

  Future<void> saveInvoiceLayoutSettings(InvoiceLayoutSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_invoicePaperSizeKey, settings.paperSize.name);
    await prefs.setString(_invoiceLanguageKey, settings.language.name);
    await prefs.setString(_invoiceEnglishFontKey, settings.englishFontFamily);
    await prefs.setString(_invoiceSinhalaFontKey, settings.sinhalaFontFamily);
    await prefs.setDouble(_invoiceMarginTopKey, settings.marginTop);
    await prefs.setDouble(_invoiceMarginRightKey, settings.marginRight);
    await prefs.setDouble(_invoiceMarginBottomKey, settings.marginBottom);
    await prefs.setDouble(_invoiceMarginLeftKey, settings.marginLeft);
  }
}
