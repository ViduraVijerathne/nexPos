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

enum PosInvoicePrintMode {
  preview('Show Preview Before Printing'),
  instant('Print Instantly');

  const PosInvoicePrintMode(this.label);

  final String label;
}

class PosPrintSettings {
  const PosPrintSettings({required this.invoicePrintMode});

  final PosInvoicePrintMode invoicePrintMode;
}

enum PosShortcutKey {
  f1('F1'),
  f2('F2'),
  f3('F3'),
  f4('F4'),
  f5('F5'),
  f6('F6'),
  f7('F7'),
  f8('F8'),
  f9('F9'),
  f10('F10'),
  f11('F11'),
  f12('F12');

  const PosShortcutKey(this.label);

  final String label;
}

class PosShortcutSettings {
  const PosShortcutSettings({
    required this.productSearchKey,
    required this.customerSearchKey,
    required this.amountPaidKey,
    required this.processPaymentKey,
  });

  final PosShortcutKey productSearchKey;
  final PosShortcutKey customerSearchKey;
  final PosShortcutKey amountPaidKey;
  final PosShortcutKey processPaymentKey;

  static const PosShortcutSettings defaults = PosShortcutSettings(
    productSearchKey: PosShortcutKey.f1,
    customerSearchKey: PosShortcutKey.f2,
    amountPaidKey: PosShortcutKey.f3,
    processPaymentKey: PosShortcutKey.f4,
  );
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

class ReportHeaderSettings {
  const ReportHeaderSettings({
    required this.title,
    required this.subtitle,
    required this.language,
    required this.englishFontFamily,
    required this.sinhalaFontFamily,
    required this.showLogo,
    required this.marginTop,
    required this.marginBottom,
  });

  final String title;
  final String subtitle;
  final InvoiceLanguage language;
  final String englishFontFamily;
  final String sinhalaFontFamily;
  final bool showLogo;
  final double marginTop;
  final double marginBottom;

  static const ReportHeaderSettings defaults = ReportHeaderSettings(
    title: '',
    subtitle: 'Comprehensive business reports with real-time data.',
    language: InvoiceLanguage.english,
    englishFontFamily: '',
    sinhalaFontFamily: 'Noto Sans Sinhala',
    showLogo: true,
    marginTop: 0,
    marginBottom: 0,
  );
}

class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const String _posTaxEnabledKey = 'settings.pos_tax_enabled';
  static const String _posTaxPercentKey = 'settings.pos_tax_percent';
  static const String _posCustomerOnlyContactKey =
      'settings.pos_customer_only_contact';
  static const String _posInvoicePrintModeKey =
      'settings.pos_invoice_print_mode';
  static const String _posShortcutProductSearchKey =
      'settings.pos_shortcut_product_search';
  static const String _posShortcutCustomerSearchKey =
      'settings.pos_shortcut_customer_search';
  static const String _posShortcutAmountPaidKey =
      'settings.pos_shortcut_amount_paid';
  static const String _posShortcutProcessPaymentKey =
      'settings.pos_shortcut_process_payment';
  static const String _invoicePaperSizeKey = 'settings.invoice_paper_size';
  static const String _invoiceLanguageKey = 'settings.invoice_language';
  static const String _invoiceEnglishFontKey = 'settings.invoice_english_font';
  static const String _invoiceSinhalaFontKey = 'settings.invoice_sinhala_font';
  static const String _invoiceMarginTopKey = 'settings.invoice_margin_top';
  static const String _invoiceMarginRightKey = 'settings.invoice_margin_right';
  static const String _invoiceMarginBottomKey =
      'settings.invoice_margin_bottom';
  static const String _invoiceMarginLeftKey = 'settings.invoice_margin_left';
  static const String _reportHeaderTitleKey = 'settings.report_header_title';
  static const String _reportHeaderSubtitleKey =
      'settings.report_header_subtitle';
  static const String _reportHeaderLanguageKey =
      'settings.report_header_language';
  static const String _reportHeaderEnglishFontKey =
      'settings.report_header_english_font';
  static const String _reportHeaderSinhalaFontKey =
      'settings.report_header_sinhala_font';
  static const String _reportHeaderShowLogoKey =
      'settings.report_header_show_logo';
  static const String _reportHeaderMarginTopKey =
      'settings.report_header_margin_top';
  static const String _reportHeaderMarginBottomKey =
      'settings.report_header_margin_bottom';

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

  Future<PosPrintSettings> loadPosPrintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMode = prefs.getString(_posInvoicePrintModeKey);
    final mode = PosInvoicePrintMode.values.firstWhere(
      (item) => item.name == rawMode,
      orElse: () => PosInvoicePrintMode.preview,
    );
    return PosPrintSettings(invoicePrintMode: mode);
  }

  Future<void> savePosPrintSettings({
    required PosInvoicePrintMode invoicePrintMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_posInvoicePrintModeKey, invoicePrintMode.name);
  }

  Future<PosShortcutSettings> loadPosShortcutSettings() async {
    final prefs = await SharedPreferences.getInstance();

    PosShortcutKey readShortcut(String storageKey, PosShortcutKey fallback) {
      final raw = prefs.getString(storageKey);
      return PosShortcutKey.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => fallback,
      );
    }

    return PosShortcutSettings(
      productSearchKey: readShortcut(
        _posShortcutProductSearchKey,
        PosShortcutSettings.defaults.productSearchKey,
      ),
      customerSearchKey: readShortcut(
        _posShortcutCustomerSearchKey,
        PosShortcutSettings.defaults.customerSearchKey,
      ),
      amountPaidKey: readShortcut(
        _posShortcutAmountPaidKey,
        PosShortcutSettings.defaults.amountPaidKey,
      ),
      processPaymentKey: readShortcut(
        _posShortcutProcessPaymentKey,
        PosShortcutSettings.defaults.processPaymentKey,
      ),
    );
  }

  Future<void> savePosShortcutSettings(PosShortcutSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _posShortcutProductSearchKey,
      settings.productSearchKey.name,
    );
    await prefs.setString(
      _posShortcutCustomerSearchKey,
      settings.customerSearchKey.name,
    );
    await prefs.setString(
      _posShortcutAmountPaidKey,
      settings.amountPaidKey.name,
    );
    await prefs.setString(
      _posShortcutProcessPaymentKey,
      settings.processPaymentKey.name,
    );
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

  Future<ReportHeaderSettings> loadReportHeaderSettings() async {
    final prefs = await SharedPreferences.getInstance();

    InvoiceLanguage readLanguage(String? raw) {
      return InvoiceLanguage.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => ReportHeaderSettings.defaults.language,
      );
    }

    return ReportHeaderSettings(
      title:
          prefs.getString(_reportHeaderTitleKey) ??
          ReportHeaderSettings.defaults.title,
      subtitle:
          prefs.getString(_reportHeaderSubtitleKey) ??
          ReportHeaderSettings.defaults.subtitle,
      language: readLanguage(prefs.getString(_reportHeaderLanguageKey)),
      englishFontFamily:
          prefs.getString(_reportHeaderEnglishFontKey) ??
          ReportHeaderSettings.defaults.englishFontFamily,
      sinhalaFontFamily:
          prefs.getString(_reportHeaderSinhalaFontKey) ??
          ReportHeaderSettings.defaults.sinhalaFontFamily,
      showLogo:
          prefs.getBool(_reportHeaderShowLogoKey) ??
          ReportHeaderSettings.defaults.showLogo,
      marginTop:
          prefs.getDouble(_reportHeaderMarginTopKey) ??
          ReportHeaderSettings.defaults.marginTop,
      marginBottom:
          prefs.getDouble(_reportHeaderMarginBottomKey) ??
          ReportHeaderSettings.defaults.marginBottom,
    );
  }

  Future<void> saveReportHeaderSettings(ReportHeaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reportHeaderTitleKey, settings.title);
    await prefs.setString(_reportHeaderSubtitleKey, settings.subtitle);
    await prefs.setString(_reportHeaderLanguageKey, settings.language.name);
    await prefs.setString(
      _reportHeaderEnglishFontKey,
      settings.englishFontFamily,
    );
    await prefs.setString(
      _reportHeaderSinhalaFontKey,
      settings.sinhalaFontFamily,
    );
    await prefs.setBool(_reportHeaderShowLogoKey, settings.showLogo);
    await prefs.setDouble(_reportHeaderMarginTopKey, settings.marginTop);
    await prefs.setDouble(_reportHeaderMarginBottomKey, settings.marginBottom);
  }
}
