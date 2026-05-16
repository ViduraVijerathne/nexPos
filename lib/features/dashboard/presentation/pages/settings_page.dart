import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../../../core/widgets/report_header_preview.dart';
import '../../../online/services/online_firebase_service.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';

enum _SettingsMenuSection {
  profile,
  themes,
  notifications,
  security,
  posSettings,
  languageRegion,
  systemPreferences,
  systemUpdates,
  about,
}

extension on _SettingsMenuSection {
  String get title => switch (this) {
    _SettingsMenuSection.profile => 'Profile Settings',
    _SettingsMenuSection.themes => 'Themes',
    _SettingsMenuSection.notifications => 'Notifications',
    _SettingsMenuSection.security => 'Security',
    _SettingsMenuSection.posSettings => 'POS Settings',
    _SettingsMenuSection.languageRegion => 'Invoice Layout',
    _SettingsMenuSection.systemPreferences => 'System Preferences',
    _SettingsMenuSection.systemUpdates => 'System Updates',
    _SettingsMenuSection.about => 'About',
  };

  IconData get icon => switch (this) {
    _SettingsMenuSection.profile => Icons.person_outline_rounded,
    _SettingsMenuSection.themes => Icons.palette_outlined,
    _SettingsMenuSection.notifications => Icons.notifications_none_rounded,
    _SettingsMenuSection.security => Icons.lock_outline_rounded,
    _SettingsMenuSection.posSettings => Icons.point_of_sale_rounded,
    _SettingsMenuSection.languageRegion => Icons.language_rounded,
    _SettingsMenuSection.systemPreferences => Icons.settings_outlined,
    _SettingsMenuSection.systemUpdates => Icons.system_update_alt_rounded,
    _SettingsMenuSection.about => Icons.info_outline_rounded,
  };
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _taxPercentController = TextEditingController();
  final TextEditingController _marginTopController = TextEditingController();
  final TextEditingController _marginRightController = TextEditingController();
  final TextEditingController _marginBottomController = TextEditingController();
  final TextEditingController _marginLeftController = TextEditingController();
  final TextEditingController _reportHeaderTitleController =
      TextEditingController();
  final TextEditingController _reportHeaderSubtitleController =
      TextEditingController();
  final TextEditingController _reportHeaderTopMarginController =
      TextEditingController();
  final TextEditingController _reportHeaderBottomMarginController =
      TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopEmailController = TextEditingController();
  final TextEditingController _shopPhoneController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingPassword = false;
  bool _isSavingPin = false;
  bool _isSavingLoginMethod = false;
  bool _isTaxEnabled = false;
  bool _touchUiEnabled = false;
  bool _createCustomerOnlyContact = false;
  bool _grnAddItemOnEnter = true;
  PosCatalogLoadMode _posCatalogLoadMode = PosCatalogLoadMode.defaultOrder;
  PosCatalogViewMode _posCatalogViewMode = PosCatalogViewMode.row;
  PosPrintSettings _posPrintSettings = PosPrintSettings.defaults;
  PosShortcutSettings _posShortcutSettings = PosShortcutSettings.defaults;
  List<Printer> _availablePrinters = const <Printer>[];
  bool _isLoadingPrinters = false;
  AppMode? _appMode;
  String _adminEmail = '';
  LoginMethod _defaultLoginMethod = LoginMethod.emailPassword;
  ShopInfo _shopInfo = const ShopInfo(
    logoPath: '',
    shopName: '',
    contactEmail: '',
    contactNumber: '',
    address: '',
  );
  InvoicePaperSize _paperSize = InvoiceLayoutSettings.defaults.paperSize;
  InvoiceLanguage _invoiceLanguage = InvoiceLayoutSettings.defaults.language;
  String _englishFontFamily = InvoiceLayoutSettings.defaults.englishFontFamily;
  String _sinhalaFontFamily = InvoiceLayoutSettings.defaults.sinhalaFontFamily;
  InvoiceLanguage _reportHeaderLanguage =
      ReportHeaderSettings.defaults.language;
  String _reportHeaderEnglishFontFamily =
      ReportHeaderSettings.defaults.englishFontFamily;
  String _reportHeaderSinhalaFontFamily =
      ReportHeaderSettings.defaults.sinhalaFontFamily;
  bool _showReportLogo = ReportHeaderSettings.defaults.showLogo;
  AppThemeStyle _selectedThemeStyle =
      AppThemeController.instance.settings.style;
  Color _selectedAccentColor = AppThemeController.instance.settings.accentColor;
  _SettingsMenuSection _selectedSection =
      _SettingsMenuSection.systemPreferences;

  static const List<DropdownMenuItem<String>> _englishFontItems = [
    DropdownMenuItem(value: '', child: Text('System Default')),
    DropdownMenuItem(value: 'Helvetica', child: Text('Helvetica')),
    DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
    DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
  ];

  static const List<DropdownMenuItem<String>> _sinhalaFontItems = [
    DropdownMenuItem(
      value: 'Noto Sans Sinhala',
      child: Text('Noto Sans Sinhala'),
    ),
    DropdownMenuItem(value: 'Iskoola Pota', child: Text('Iskoola Pota')),
    DropdownMenuItem(value: 'Nirmala UI', child: Text('Nirmala UI')),
  ];

  static final List<DropdownMenuItem<PosShortcutKey>> _shortcutItems =
      PosShortcutKey.values
          .map(
            (key) => DropdownMenuItem<PosShortcutKey>(
              value: key,
              child: Text(key.label),
            ),
          )
          .toList();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _taxPercentController.dispose();
    _marginTopController.dispose();
    _marginRightController.dispose();
    _marginBottomController.dispose();
    _marginLeftController.dispose();
    _reportHeaderTitleController.dispose();
    _reportHeaderSubtitleController.dispose();
    _reportHeaderTopMarginController.dispose();
    _reportHeaderBottomMarginController.dispose();
    _shopNameController.dispose();
    _shopEmailController.dispose();
    _shopPhoneController.dispose();
    _shopAddressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmNewPinController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final taxSettings = await AppSettingsService.instance
          .loadPosTaxSettings();
      final customerSettings = await AppSettingsService.instance
          .loadPosCustomerSettings();
      final posCatalogSettings = await AppSettingsService.instance
          .loadPosCatalogSettings();
      final touchUiSettings = await AppSettingsService.instance
          .loadTouchUiSettings();
      final grnEntrySettings = await AppSettingsService.instance
          .loadGrnEntrySettings();
      final posPrintSettings = await AppSettingsService.instance
          .loadPosPrintSettings();
      final posShortcutSettings = await AppSettingsService.instance
          .loadPosShortcutSettings();
      final invoiceSettings = await AppSettingsService.instance
          .loadInvoiceLayoutSettings();
      final reportHeaderSettings = await AppSettingsService.instance
          .loadReportHeaderSettings();
      final setupState = await SetupService.instance.loadState();

      final printers = await Printing.listPrinters();

      if (!mounted) {
        return;
      }

      setState(() {
        _isTaxEnabled = taxSettings.isTaxEnabled;
        _taxPercentController.text = _formatNumber(taxSettings.taxPercent);
        _touchUiEnabled = touchUiSettings.isEnabled;
        _appMode = setupState.mode;
        _adminEmail = setupState.adminEmail;
        _defaultLoginMethod =
            setupState.defaultLoginMethod ?? LoginMethod.emailPassword;
        _createCustomerOnlyContact = customerSettings.createCustomerOnlyContact;
        _posCatalogLoadMode = posCatalogSettings.defaultLoadMode;
        _posCatalogViewMode = posCatalogSettings.defaultViewMode;
        _grnAddItemOnEnter = grnEntrySettings.addItemOnEnter;
        _posPrintSettings = posPrintSettings;
        _posShortcutSettings = posShortcutSettings;
        _availablePrinters = printers;
        _shopInfo = setupState.shopInfo;
        _paperSize = invoiceSettings.paperSize;
        _invoiceLanguage = invoiceSettings.language;
        _englishFontFamily = invoiceSettings.englishFontFamily;
        _sinhalaFontFamily = invoiceSettings.sinhalaFontFamily;
        _reportHeaderLanguage = reportHeaderSettings.language;
        _reportHeaderEnglishFontFamily = reportHeaderSettings.englishFontFamily;
        _reportHeaderSinhalaFontFamily = reportHeaderSettings.sinhalaFontFamily;
        _showReportLogo = reportHeaderSettings.showLogo;
        _selectedThemeStyle = AppThemeController.instance.settings.style;
        _selectedAccentColor = AppThemeController.instance.settings.accentColor;
        _marginTopController.text = _formatNumber(invoiceSettings.marginTop);
        _marginRightController.text = _formatNumber(
          invoiceSettings.marginRight,
        );
        _marginBottomController.text = _formatNumber(
          invoiceSettings.marginBottom,
        );
        _marginLeftController.text = _formatNumber(invoiceSettings.marginLeft);
        _reportHeaderTitleController.text = reportHeaderSettings.title;
        _reportHeaderSubtitleController.text = reportHeaderSettings.subtitle;
        _reportHeaderTopMarginController.text = _formatNumber(
          reportHeaderSettings.marginTop,
        );
        _reportHeaderBottomMarginController.text = _formatNumber(
          reportHeaderSettings.marginBottom,
        );
        _shopNameController.text = setupState.shopInfo.shopName;
        _shopEmailController.text = setupState.shopInfo.contactEmail;
        _shopPhoneController.text = setupState.shopInfo.contactNumber;
        _shopAddressController.text = setupState.shopInfo.address;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load settings: $error');
    }
  }

  Future<void> _saveSettings() async {
    final taxPercent = double.tryParse(_taxPercentController.text.trim());
    final marginTop = double.tryParse(_marginTopController.text.trim());
    final marginRight = double.tryParse(_marginRightController.text.trim());
    final marginBottom = double.tryParse(_marginBottomController.text.trim());
    final marginLeft = double.tryParse(_marginLeftController.text.trim());
    final reportHeaderMarginTop = double.tryParse(
      _reportHeaderTopMarginController.text.trim(),
    );
    final reportHeaderMarginBottom = double.tryParse(
      _reportHeaderBottomMarginController.text.trim(),
    );
    final uniqueShortcuts = <PosShortcutKey>{
      _posShortcutSettings.productSearchKey,
      _posShortcutSettings.customerSearchKey,
      _posShortcutSettings.amountPaidKey,
      _posShortcutSettings.processPaymentKey,
    };

    if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
      AppToast.error('Enter a valid tax percentage between 0 and 100');
      return;
    }

    if (uniqueShortcuts.length != 4) {
      AppToast.error('Assign a different shortcut key for each POS action');
      return;
    }

    if ([
      marginTop,
      marginRight,
      marginBottom,
      marginLeft,
    ].any((value) => value == null || value < 0 || value > 100)) {
      AppToast.error('Enter valid print margins between 0 and 100');
      return;
    }

    if ([
      reportHeaderMarginTop,
      reportHeaderMarginBottom,
    ].any((value) => value == null || value < 0 || value > 100)) {
      AppToast.error('Enter valid report header margins between 0 and 100');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AppSettingsService.instance.savePosTaxSettings(
        isTaxEnabled: _isTaxEnabled,
        taxPercent: taxPercent,
      );
      await AppSettingsService.instance.savePosCustomerSettings(
        createCustomerOnlyContact: _createCustomerOnlyContact,
      );
      await AppSettingsService.instance.savePosCatalogSettings(
        defaultLoadMode: _posCatalogLoadMode,
        defaultViewMode: _posCatalogViewMode,
      );
      await AppSettingsService.instance.saveTouchUiSettings(
        isEnabled: _touchUiEnabled,
      );
      await AppSettingsService.instance.saveGrnEntrySettings(
        addItemOnEnter: _grnAddItemOnEnter,
      );
      await AppSettingsService.instance.savePosPrintSettings(
        invoicePrintMode: _posPrintSettings.invoicePrintMode,
        restaurantExtensionEnabled:
            _posPrintSettings.restaurantExtensionEnabled,
        kotPreviewEnabled: _posPrintSettings.kotPreviewEnabled,
        invoicePrinterName: _posPrintSettings.invoicePrinterName,
        invoicePrinterUrl: _posPrintSettings.invoicePrinterUrl,
        kotPrinterName: _posPrintSettings.kotPrinterName,
        kotPrinterUrl: _posPrintSettings.kotPrinterUrl,
      );
      await AppSettingsService.instance.savePosShortcutSettings(
        _posShortcutSettings,
      );
      await AppSettingsService.instance.saveInvoiceLayoutSettings(
        InvoiceLayoutSettings(
          paperSize: _paperSize,
          language: _invoiceLanguage,
          englishFontFamily: _englishFontFamily,
          sinhalaFontFamily: _sinhalaFontFamily,
          marginTop: marginTop!,
          marginRight: marginRight!,
          marginBottom: marginBottom!,
          marginLeft: marginLeft!,
        ),
      );
      await AppSettingsService.instance.saveReportHeaderSettings(
        ReportHeaderSettings(
          title: _reportHeaderTitleController.text.trim(),
          subtitle: _reportHeaderSubtitleController.text.trim(),
          language: _reportHeaderLanguage,
          englishFontFamily: _reportHeaderEnglishFontFamily,
          sinhalaFontFamily: _reportHeaderSinhalaFontFamily,
          showLogo: _showReportLogo,
          marginTop: reportHeaderMarginTop!,
          marginBottom: reportHeaderMarginBottom!,
        ),
      );
      if (!mounted) {
        return;
      }
      AppToast.success('Settings saved');
    } catch (error) {
      AppToast.error('Failed to save settings: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _refreshPrinters() async {
    setState(() => _isLoadingPrinters = true);
    try {
      final printers = await Printing.listPrinters();
      if (!mounted) {
        return;
      }
      setState(() => _availablePrinters = printers);
      AppToast.success('Printer list refreshed');
    } catch (error) {
      AppToast.error('Failed to load printers: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrinters = false);
      }
    }
  }

  void _setInvoicePrinter(String? printerUrl) {
    final printer = _findPrinterByUrl(printerUrl);
    setState(() {
      _posPrintSettings = _posPrintSettings.copyWith(
        invoicePrinterUrl: printer?.url ?? '',
        invoicePrinterName: printer?.name ?? '',
      );
    });
  }

  void _setKotPrinter(String? printerUrl) {
    final printer = _findPrinterByUrl(printerUrl);
    setState(() {
      _posPrintSettings = _posPrintSettings.copyWith(
        kotPrinterUrl: printer?.url ?? '',
        kotPrinterName: printer?.name ?? '',
      );
    });
  }

  Printer? _findPrinterByUrl(String? printerUrl) {
    if (printerUrl == null || printerUrl.trim().isEmpty) {
      return null;
    }
    for (final printer in _availablePrinters) {
      if (printer.url == printerUrl) {
        return printer;
      }
    }
    return null;
  }

  void _resetInvoiceLayoutDefaults() {
    final defaults = InvoiceLayoutSettings.defaults;
    setState(() {
      _paperSize = defaults.paperSize;
      _invoiceLanguage = defaults.language;
      _englishFontFamily = defaults.englishFontFamily;
      _sinhalaFontFamily = defaults.sinhalaFontFamily;
      _marginTopController.text = _formatNumber(defaults.marginTop);
      _marginRightController.text = _formatNumber(defaults.marginRight);
      _marginBottomController.text = _formatNumber(defaults.marginBottom);
      _marginLeftController.text = _formatNumber(defaults.marginLeft);
    });
  }

  void _resetReportHeaderDefaults() {
    final defaults = ReportHeaderSettings.defaults;
    setState(() {
      _reportHeaderTitleController.text = defaults.title;
      _reportHeaderSubtitleController.text = defaults.subtitle;
      _reportHeaderLanguage = defaults.language;
      _reportHeaderEnglishFontFamily = defaults.englishFontFamily;
      _reportHeaderSinhalaFontFamily = defaults.sinhalaFontFamily;
      _showReportLogo = defaults.showLogo;
      _reportHeaderTopMarginController.text = _formatNumber(defaults.marginTop);
      _reportHeaderBottomMarginController.text = _formatNumber(
        defaults.marginBottom,
      );
    });
  }

  Future<void> _pickShopLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final savedPath = await SetupService.instance.saveShopLogo(
      result.files.first,
    );
    if (savedPath == null) {
      AppToast.error('Unable to save logo');
      return;
    }

    setState(() {
      _shopInfo = ShopInfo(
        logoPath: savedPath,
        shopName: _shopNameController.text.trim(),
        contactEmail: _shopEmailController.text.trim(),
        contactNumber: _shopPhoneController.text.trim(),
        address: _shopAddressController.text.trim(),
      );
    });
    AppToast.success('Shop logo updated');
  }

  Future<void> _saveProfileSettings() async {
    if (_shopNameController.text.trim().isEmpty) {
      AppToast.error('Shop name is required');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedShopInfo = ShopInfo(
        logoPath: _shopInfo.logoPath,
        shopName: _shopNameController.text.trim(),
        contactEmail: _shopEmailController.text.trim(),
        contactNumber: _shopPhoneController.text.trim(),
        address: _shopAddressController.text.trim(),
      );
      await SetupService.instance.saveShopInfo(updatedShopInfo);
      if (!mounted) {
        return;
      }
      setState(() {
        _shopInfo = updatedShopInfo;
      });
      AppToast.success('Profile settings updated');
    } catch (error) {
      AppToast.error('Failed to save profile settings: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveDefaultLoginMethod(LoginMethod method) async {
    setState(() => _isSavingLoginMethod = true);
    try {
      await SetupService.instance.saveDefaultLoginMethod(method);
      if (!mounted) {
        return;
      }
      setState(() => _defaultLoginMethod = method);
      AppToast.success('Default login method updated');
    } catch (error) {
      AppToast.error('Failed to update login method: $error');
    } finally {
      if (mounted) {
        setState(() => _isSavingLoginMethod = false);
      }
    }
  }

  Future<void> _savePosCatalogPreferences() async {
    try {
      await AppSettingsService.instance.savePosCatalogSettings(
        defaultLoadMode: _posCatalogLoadMode,
        defaultViewMode: _posCatalogViewMode,
      );
      if (!mounted) {
        return;
      }
      AppToast.success('POS settings updated');
    } catch (error) {
      AppToast.error('Failed to update POS settings: $error');
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmNewPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      AppToast.error('Fill all password fields');
      return;
    }
    if (newPassword.length < 4) {
      AppToast.error('New password should be at least 4 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      AppToast.error('New password confirmation does not match');
      return;
    }
    if (_adminEmail.trim().isEmpty) {
      AppToast.error('Admin account information is missing');
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      if (_appMode == AppMode.online) {
        await OnlineFirebaseService.instance.changePassword(
          email: _adminEmail,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      } else {
        final changed = await SetupService.instance.changeAdminPassword(
          email: _adminEmail,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        if (!changed) {
          AppToast.error('Current password is incorrect');
          return;
        }
      }

      await SetupService.instance.saveAdminAccount(
        email: _adminEmail,
        password: newPassword,
      );

      final state = await SetupService.instance.loadState();
      if (_appMode == AppMode.online && state.pin.length == 4) {
        await SetupService.instance.saveOnlinePinCredentials(
          email: _adminEmail,
          password: newPassword,
          pin: state.pin,
        );
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
      AppToast.success('Password updated successfully');
    } catch (error) {
      AppToast.error('Failed to change password: $error');
    } finally {
      if (mounted) {
        setState(() => _isSavingPassword = false);
      }
    }
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmNewPinController.text.trim();

    if ([currentPin, newPin, confirmPin].any((value) => value.length != 4)) {
      AppToast.error('Enter valid 4 digit PIN values');
      return;
    }
    if (newPin != confirmPin) {
      AppToast.error('New PIN confirmation does not match');
      return;
    }

    setState(() => _isSavingPin = true);
    try {
      ({String email, String password})? onlineCredentials;
      if (_appMode == AppMode.online) {
        onlineCredentials = await SetupService.instance
            .readOnlinePinCredentials(currentPin);
        if (onlineCredentials == null) {
          AppToast.error(
            'Online PIN credentials are missing. Please login with password and reconfigure the PIN.',
          );
          return;
        }
      }

      final changed = await SetupService.instance.changePin(
        currentPin: currentPin,
        newPin: newPin,
      );
      if (!changed) {
        AppToast.error('Current PIN is incorrect');
        return;
      }

      if (_appMode == AppMode.online && onlineCredentials != null) {
        await SetupService.instance.saveOnlinePinCredentials(
          email: onlineCredentials.email,
          password: onlineCredentials.password,
          pin: newPin,
        );
      }

      _currentPinController.clear();
      _newPinController.clear();
      _confirmNewPinController.clear();
      AppToast.success('PIN updated successfully');
    } catch (error) {
      AppToast.error('Failed to change PIN: $error');
    } finally {
      if (mounted) {
        setState(() => _isSavingPin = false);
      }
    }
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  InvoiceLayoutSettings get _currentInvoiceSettings => InvoiceLayoutSettings(
    paperSize: _paperSize,
    language: _invoiceLanguage,
    englishFontFamily: _englishFontFamily,
    sinhalaFontFamily: _sinhalaFontFamily,
    marginTop:
        double.tryParse(_marginTopController.text.trim()) ??
        InvoiceLayoutSettings.defaults.marginTop,
    marginRight:
        double.tryParse(_marginRightController.text.trim()) ??
        InvoiceLayoutSettings.defaults.marginRight,
    marginBottom:
        double.tryParse(_marginBottomController.text.trim()) ??
        InvoiceLayoutSettings.defaults.marginBottom,
    marginLeft:
        double.tryParse(_marginLeftController.text.trim()) ??
        InvoiceLayoutSettings.defaults.marginLeft,
  );

  InvoicePreviewData get _sampleInvoice => const InvoicePreviewData(
    invoiceNumber: '0098',
    customerName: 'Walk-In Customer',
    customerMobile: '',
    dateTimeText: '04/07/2026 14:23',
    items: [
      InvoicePreviewLine(name: 'chili powder', quantity: 1, unitPrice: 1250),
      InvoicePreviewLine(name: 'curry powder', quantity: 1, unitPrice: 1250),
    ],
    subtotal: 2500,
    discount: 0,
    tax: 0,
    total: 2500,
    paymentMethod: 'Cash',
    paidAmount: 3000,
    cashPaidAmount: 3000,
    cardPaidAmount: 0,
    balance: 500,
  );

  ReportHeaderSettings get _currentReportHeaderSettings => ReportHeaderSettings(
    title: _reportHeaderTitleController.text.trim(),
    subtitle: _reportHeaderSubtitleController.text.trim(),
    language: _reportHeaderLanguage,
    englishFontFamily: _reportHeaderEnglishFontFamily,
    sinhalaFontFamily: _reportHeaderSinhalaFontFamily,
    showLogo: _showReportLogo,
    marginTop:
        double.tryParse(_reportHeaderTopMarginController.text.trim()) ??
        ReportHeaderSettings.defaults.marginTop,
    marginBottom:
        double.tryParse(_reportHeaderBottomMarginController.text.trim()) ??
        ReportHeaderSettings.defaults.marginBottom,
  );

  Widget _buildResponsiveColumns({
    required List<Widget> children,
    double spacing = 16,
    double breakpoint = 760,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResponsiveActionRow({
    required Widget leading,
    required Widget trailing,
    double breakpoint = 760,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [leading, const SizedBox(height: 12), trailing],
          );
        }

        return Row(
          children: [
            leading,
            const Spacer(),
            Flexible(child: trailing),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1120;
        final isNarrow = constraints.maxWidth < 640;
        final horizontalPadding = constraints.maxWidth < 640 ? 12.0 : 18.0;
        final verticalGap = constraints.maxWidth < 640 ? 14.0 : 20.0;
        final menuCard = _MenuCard(
          selectedSection: _selectedSection,
          onSelected: (section) {
            setState(() => _selectedSection = section);
          },
        );
        final contentCard = _ContentCard(child: _buildSelectedSectionContent());

        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryTeal,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: isNarrow ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your system preferences and configurations.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: verticalGap),
                    Expanded(
                      child: isCompact
                          ? SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  menuCard,
                                  SizedBox(height: verticalGap),
                                  contentCard,
                                ],
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 375, child: menuCard),
                                const SizedBox(width: 18),
                                Expanded(child: contentCard),
                              ],
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSelectedSectionContent() {
    return switch (_selectedSection) {
      _SettingsMenuSection.profile => _buildProfileSection(),
      _SettingsMenuSection.themes => _buildThemesSection(),
      _SettingsMenuSection.notifications => _InfoPanel(
        title: 'Notifications',
        description:
            'Email alerts, low-stock notifications, and reminder controls are reserved for the upcoming notification module.',
        icon: Icons.notifications_none_rounded,
      ),
      _SettingsMenuSection.security => _buildSecuritySection(),
      _SettingsMenuSection.posSettings => _buildPosSettingsSection(),
      _SettingsMenuSection.languageRegion => _buildLanguageRegionSection(),
      _SettingsMenuSection.systemPreferences =>
        _buildSystemPreferencesSection(),
      _SettingsMenuSection.systemUpdates => _InfoPanel(
        title: 'System Updates',
        description:
            'Online update delivery is not supported yet. Local builds can still be updated manually by replacing the desktop application.',
        icon: Icons.system_update_alt_rounded,
      ),
      _SettingsMenuSection.about => _buildAboutSection(),
    };
  }

  Widget _buildSystemPreferencesSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Preferences',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'POS Tax Settings',
            child: Column(
              children: [
                _SwitchTile(
                  title: 'Show Tax In POS',
                  description: _isTaxEnabled
                      ? 'Tax row and tax amount are enabled in the billing summary.'
                      : 'Tax is hidden by default until you enable it.',
                  value: _isTaxEnabled,
                  onChanged: (value) {
                    setState(() => _isTaxEnabled = value);
                  },
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Tax Percentage'),
                const SizedBox(height: 8),
                SizedBox(
                  width: 260,
                  child: _NumberField(
                    controller: _taxPercentController,
                    suffixText: '%',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'POS Customer Flow',
            child: _SwitchTile(
              title: 'Create Customer Only Contact Number',
              description: _createCustomerOnlyContact
                  ? 'POS can create a customer quickly with just the mobile number.'
                  : 'POS will ask for full customer details before creating a new customer.',
              value: _createCustomerOnlyContact,
              onChanged: (value) {
                setState(() => _createCustomerOnlyContact = value);
              },
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'GRN Quick Entry',
            child: _SwitchTile(
              title: 'Add Item On Enter',
              description: _grnAddItemOnEnter
                  ? 'When all item fields are filled in the GRN dialog, pressing Enter will add the item instantly.'
                  : 'Cashiers must click `Add Item to GRN` manually in the GRN dialog.',
              value: _grnAddItemOnEnter,
              onChanged: (value) {
                setState(() => _grnAddItemOnEnter = value);
              },
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'POS Invoice Printing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose what happens after the cashier presses `Process Payment` in POS.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: PosInvoicePrintMode.values.map((mode) {
                    final selected = _posPrintSettings.invoicePrintMode == mode;
                    return SizedBox(
                      width: 260,
                      child: _SelectableCard(
                        selected: selected,
                        icon: mode == PosInvoicePrintMode.preview
                            ? Icons.preview_outlined
                            : Icons.print_outlined,
                        label: mode.label,
                        onTap: () {
                          setState(() {
                            _posPrintSettings = _posPrintSettings.copyWith(
                              invoicePrintMode: mode,
                            );
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Restaurant Extension',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SwitchTile(
                  title: 'Enable Restaurant Printing',
                  description: _posPrintSettings.restaurantExtensionEnabled
                      ? 'POS will print both the customer invoice and a KOT after checkout.'
                      : 'Enable this to print invoice and kitchen order ticket separately for restaurant billing.',
                  value: _posPrintSettings.restaurantExtensionEnabled,
                  onChanged: (value) {
                    setState(() {
                      _posPrintSettings = _posPrintSettings.copyWith(
                        restaurantExtensionEnabled: value,
                      );
                    });
                  },
                ),
                if (_posPrintSettings.restaurantExtensionEnabled) ...[
                  const SizedBox(height: 16),
                  _SwitchTile(
                    title: 'Preview KOT Before Printing',
                    description: _posPrintSettings.kotPreviewEnabled
                        ? 'A preview dialog will appear before the kitchen order ticket is printed.'
                        : 'KOT will print immediately after the invoice without showing a preview.',
                    value: _posPrintSettings.kotPreviewEnabled,
                    onChanged: (value) {
                      setState(() {
                        _posPrintSettings = _posPrintSettings.copyWith(
                          kotPreviewEnabled: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _availablePrinters.isEmpty
                              ? 'No printers loaded yet. Refresh the printer list after connecting your printers.'
                              : 'Choose which printers should handle invoice and KOT printing.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoadingPrinters ? null : _refreshPrinters,
                        icon: Icon(
                          _isLoadingPrinters
                              ? Icons.sync_rounded
                              : Icons.print_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _isLoadingPrinters
                              ? 'Loading...'
                              : 'Refresh Printers',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Invoice Printer'),
                            const SizedBox(height: 8),
                            _PrinterDropdownField(
                              value: _posPrintSettings.hasInvoicePrinter
                                  ? _posPrintSettings.invoicePrinterUrl
                                  : null,
                              selectedLabel:
                                  _posPrintSettings.invoicePrinterName,
                              printers: _availablePrinters,
                              hintText: 'Select invoice printer',
                              onChanged: _setInvoicePrinter,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('KOT Printer'),
                            const SizedBox(height: 8),
                            _PrinterDropdownField(
                              value: _posPrintSettings.hasKotPrinter
                                  ? _posPrintSettings.kotPrinterUrl
                                  : null,
                              selectedLabel: _posPrintSettings.kotPrinterName,
                              printers: _availablePrinters,
                              hintText: 'Select KOT printer',
                              onChanged: _setKotPrinter,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'POS Keyboard Shortcuts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashier shortcuts for quickly focusing POS fields and processing payments.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Product Search'),
                          const SizedBox(height: 8),
                          _ShortcutDropdownField(
                            value: _posShortcutSettings.productSearchKey,
                            items: _shortcutItems,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _posShortcutSettings = PosShortcutSettings(
                                  productSearchKey: value,
                                  customerSearchKey:
                                      _posShortcutSettings.customerSearchKey,
                                  amountPaidKey:
                                      _posShortcutSettings.amountPaidKey,
                                  processPaymentKey:
                                      _posShortcutSettings.processPaymentKey,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Customer Search'),
                          const SizedBox(height: 8),
                          _ShortcutDropdownField(
                            value: _posShortcutSettings.customerSearchKey,
                            items: _shortcutItems,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _posShortcutSettings = PosShortcutSettings(
                                  productSearchKey:
                                      _posShortcutSettings.productSearchKey,
                                  customerSearchKey: value,
                                  amountPaidKey:
                                      _posShortcutSettings.amountPaidKey,
                                  processPaymentKey:
                                      _posShortcutSettings.processPaymentKey,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Amount Paid'),
                          const SizedBox(height: 8),
                          _ShortcutDropdownField(
                            value: _posShortcutSettings.amountPaidKey,
                            items: _shortcutItems,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _posShortcutSettings = PosShortcutSettings(
                                  productSearchKey:
                                      _posShortcutSettings.productSearchKey,
                                  customerSearchKey:
                                      _posShortcutSettings.customerSearchKey,
                                  amountPaidKey: value,
                                  processPaymentKey:
                                      _posShortcutSettings.processPaymentKey,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Process Payment'),
                          const SizedBox(height: 8),
                          _ShortcutDropdownField(
                            value: _posShortcutSettings.processPaymentKey,
                            items: _shortcutItems,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _posShortcutSettings = PosShortcutSettings(
                                  productSearchKey:
                                      _posShortcutSettings.productSearchKey,
                                  customerSearchKey:
                                      _posShortcutSettings.customerSearchKey,
                                  amountPaidKey:
                                      _posShortcutSettings.amountPaidKey,
                                  processPaymentKey: value,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final hasLogo =
        _shopInfo.logoPath.trim().isNotEmpty &&
        File(_shopInfo.logoPath).existsSync();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Shop Preview',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;
                final logo = Container(
                  height: 104,
                  width: 104,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasLogo
                      ? Image.file(File(_shopInfo.logoPath), fit: BoxFit.cover)
                      : Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopInfo.shopName.trim().isEmpty
                          ? 'Shop name not set'
                          : _shopInfo.shopName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PreviewInfoText(
                      icon: Icons.email_outlined,
                      text: _shopInfo.contactEmail.trim().isEmpty
                          ? 'No contact email'
                          : _shopInfo.contactEmail,
                    ),
                    const SizedBox(height: 6),
                    _PreviewInfoText(
                      icon: Icons.call_outlined,
                      text: _shopInfo.contactNumber.trim().isEmpty
                          ? 'No contact number'
                          : _shopInfo.contactNumber,
                    ),
                    const SizedBox(height: 6),
                    _PreviewInfoText(
                      icon: Icons.location_on_outlined,
                      text: _shopInfo.address.trim().isEmpty
                          ? 'No address'
                          : _shopInfo.address,
                    ),
                  ],
                );
                final action = OutlinedButton.icon(
                  onPressed: _pickShopLogo,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Change Logo'),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      logo,
                      const SizedBox(height: 16),
                      details,
                      const SizedBox(height: 16),
                      action,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    logo,
                    const SizedBox(width: 18),
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Update Shop Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Shop Name'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _shopNameController,
                  hintText: 'Enter shop name',
                ),
                const SizedBox(height: 14),
                _buildResponsiveColumns(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Contact Email'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _shopEmailController,
                          hintText: 'Enter contact email',
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Contact Number'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _shopPhoneController,
                          hintText: 'Enter contact number',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Address'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _shopAddressController,
                  hintText: 'Enter shop address',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfileSettings,
              child: Text(_isSaving ? 'Saving...' : 'Update Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Themes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Light Theme Styles',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: AppThemeStyle.values.map((style) {
                    final selected = _selectedThemeStyle == style;
                    return SizedBox(
                      width: 210,
                      child: _ThemeStyleCard(
                        title: style.label,
                        selected: selected,
                        previewColor: switch (style) {
                          AppThemeStyle.defaultLight => const Color(0xFFF7FAFC),
                          AppThemeStyle.skyLight => const Color(0xFFF4F8FF),
                          AppThemeStyle.sageLight => const Color(0xFFF5FBF7),
                          AppThemeStyle.sandLight => const Color(0xFFFBF8F3),
                        },
                        onTap: () async {
                          setState(() => _selectedThemeStyle = style);
                          await AppThemeController.instance.updateTheme(
                            style: style,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Accent Color',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the primary accent color used across buttons, highlights, active navigation, and focused inputs.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppThemeController.accentPresets.map((color) {
                    final selected = _selectedAccentColor.value == color.value;
                    return _AccentColorOption(
                      color: color,
                      selected: selected,
                      onTap: () async {
                        setState(() => _selectedAccentColor = color);
                        await AppThemeController.instance.updateTheme(
                          accentColor: color,
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Touchscreen Support',
            child: _SwitchTile(
              title: 'Enable Touchscreen Mode',
              description: _touchUiEnabled
                  ? 'Sidebar navigation is hidden and a large launcher screen is used for touch-friendly navigation.'
                  : 'Keep the classic sidebar layout for keyboard and mouse driven workflows.',
              value: _touchUiEnabled,
              onChanged: (value) async {
                setState(() => _touchUiEnabled = value);
                await AppSettingsService.instance.saveTouchUiSettings(
                  isEnabled: value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosSettingsSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POS Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control how the POS product list loads before the cashier starts searching.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Default Product Loading',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When the POS search box is empty, load stock items using one of these strategies.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: PosCatalogLoadMode.values.map((mode) {
                    final isSelected = _posCatalogLoadMode == mode;
                    return SizedBox(
                      width: 260,
                      child: _SelectableCard(
                        selected: isSelected,
                        icon: switch (mode) {
                          PosCatalogLoadMode.defaultOrder =>
                            Icons.view_stream_rounded,
                          PosCatalogLoadMode.quickSelling =>
                            Icons.local_fire_department_outlined,
                          PosCatalogLoadMode.mostSelling =>
                            Icons.trending_up_rounded,
                          PosCatalogLoadMode.highStock =>
                            Icons.inventory_2_outlined,
                        },
                        label: mode.label,
                        onTap: () async {
                          setState(() => _posCatalogLoadMode = mode);
                          await _savePosCatalogPreferences();
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  switch (_posCatalogLoadMode) {
                    PosCatalogLoadMode.defaultOrder =>
                      'Uses the current standard catalog order.',
                    PosCatalogLoadMode.quickSelling =>
                      'Shows only products marked as quick selling in the product form.',
                    PosCatalogLoadMode.mostSelling =>
                      'Brings forward products based on your invoice sales history.',
                    PosCatalogLoadMode.highStock =>
                      'Shows products with the highest available stock first.',
                  },
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Default Stock View',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how stock items should appear in the POS product area before searching.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: PosCatalogViewMode.values.map((mode) {
                    final isSelected = _posCatalogViewMode == mode;
                    return SizedBox(
                      width: 260,
                      child: _SelectableCard(
                        selected: isSelected,
                        icon: mode == PosCatalogViewMode.row
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                        label: mode.label,
                        onTap: () async {
                          setState(() => _posCatalogViewMode = mode);
                          await _savePosCatalogPreferences();
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  _posCatalogViewMode == PosCatalogViewMode.row
                      ? 'Row mode keeps the current cashier-friendly detailed stock rows.'
                      : 'Compact mode shows square product tiles with only the product name and selling price.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your login method, password, and PIN for both offline and online access.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Login Access',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'App Mode',
                  value: _appMode?.label ?? 'Not configured',
                ),
                _InfoRow(
                  label: 'Admin Email',
                  value: _adminEmail.isEmpty ? '-' : _adminEmail,
                  expandValue: true,
                ),
                const SizedBox(height: 8),
                const _FieldLabel('Default Login Method'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: LoginMethod.values.map((method) {
                    final selected = _defaultLoginMethod == method;
                    return SizedBox(
                      width: 220,
                      child: _SelectableCard(
                        selected: selected,
                        icon: method == LoginMethod.emailPassword
                            ? Icons.lock_outline_rounded
                            : Icons.pin_outlined,
                        label: method.label,
                        onTap: _isSavingLoginMethod
                            ? () {}
                            : () => _saveDefaultLoginMethod(method),
                      ),
                    );
                  }).toList(),
                ),
                if (_isSavingLoginMethod) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Updating login preference...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Change Password',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponsiveColumns(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Current Password'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _currentPasswordController,
                          hintText: 'Enter current password',
                          obscureText: true,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('New Password'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _newPasswordController,
                          hintText: 'Enter new password',
                          obscureText: true,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Confirm New Password'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _confirmNewPasswordController,
                  hintText: 'Re-enter new password',
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSavingPassword ? null : _changePassword,
                    child: _isSavingPassword
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Change PIN',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponsiveColumns(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Current PIN'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _currentPinController,
                          hintText: 'Enter current 4 digit PIN',
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('New PIN'),
                        const SizedBox(height: 8),
                        _TextInputField(
                          controller: _newPinController,
                          hintText: 'Enter new 4 digit PIN',
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Confirm New PIN'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _confirmNewPinController,
                  hintText: 'Re-enter new PIN',
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSavingPin ? null : _changePin,
                    child: _isSavingPin
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update PIN'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRegionSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Layout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Invoice Language & Fonts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  children: InvoiceLanguage.values.map((language) {
                    final selected = _invoiceLanguage == language;
                    return ChoiceChip(
                      label: Text(language.label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _invoiceLanguage = language);
                      },
                      selectedColor: AppColors.primaryLight,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primaryTeal
                            : const Color(0xFFE3EAF2),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryTeal
                            : const Color(0xFF445166),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _buildResponsiveColumns(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('English Font'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _englishFontFamily,
                          items: _englishFontItems,
                          onChanged: (value) {
                            setState(() => _englishFontFamily = value ?? '');
                          },
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Sinhala Font'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _sinhalaFontFamily,
                          items: _sinhalaFontItems,
                          onChanged: (value) {
                            setState(() {
                              _sinhalaFontFamily =
                                  value ??
                                  InvoiceLayoutSettings
                                      .defaults
                                      .sinhalaFontFamily;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Invoice Paper & Margins',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Paper Size'),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 760;
                    if (isCompact) {
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < InvoicePaperSize.values.length;
                            index++
                          ) ...[
                            SizedBox(
                              width: double.infinity,
                              child: _SelectableCard(
                                selected:
                                    _paperSize ==
                                    InvoicePaperSize.values[index],
                                icon:
                                    InvoicePaperSize.values[index] ==
                                        InvoicePaperSize.thermal80mm
                                    ? Icons.receipt_long_outlined
                                    : Icons.description_outlined,
                                label: InvoicePaperSize.values[index].label,
                                onTap: () => setState(
                                  () => _paperSize =
                                      InvoicePaperSize.values[index],
                                ),
                              ),
                            ),
                            if (index != InvoicePaperSize.values.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: InvoicePaperSize.values.map((size) {
                        final selected = _paperSize == size;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: size == InvoicePaperSize.thermal80mm
                                  ? 12
                                  : 0,
                            ),
                            child: _SelectableCard(
                              selected: selected,
                              icon: size == InvoicePaperSize.thermal80mm
                                  ? Icons.receipt_long_outlined
                                  : Icons.description_outlined,
                              label: size.label,
                              onTap: () => setState(() => _paperSize = size),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _buildResponsiveColumns(
                  spacing: 12,
                  children: [
                    _LabeledNumberField(
                      label: 'Top Margin',
                      controller: _marginTopController,
                    ),
                    _LabeledNumberField(
                      label: 'Right Margin',
                      controller: _marginRightController,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildResponsiveColumns(
                  spacing: 12,
                  children: [
                    _LabeledNumberField(
                      label: 'Bottom Margin',
                      controller: _marginBottomController,
                    ),
                    _LabeledNumberField(
                      label: 'Left Margin',
                      controller: _marginLeftController,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Invoice Preview',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponsiveActionRow(
                  leading: TextButton.icon(
                    onPressed: _resetInvoiceLayoutDefaults,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Default Layout'),
                  ),
                  trailing: Text(
                    'Shop logo and title come from setup information.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  child: Center(
                    child: InvoicePreviewCard(
                      shopInfo: _shopInfo,
                      settings: _currentInvoiceSettings,
                      preview: _sampleInvoice,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Report Header Designer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Header Title'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _reportHeaderTitleController,
                  hintText: 'Leave empty to use shop name',
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Header Subtitle'),
                const SizedBox(height: 8),
                _TextInputField(
                  controller: _reportHeaderSubtitleController,
                  hintText: 'Enter report header subtitle',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _SwitchTile(
                  title: 'Show Shop Logo',
                  description:
                      'Use the setup logo inside the reports header layout.',
                  value: _showReportLogo,
                  onChanged: (value) {
                    setState(() => _showReportLogo = value);
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: InvoiceLanguage.values.map((language) {
                    final selected = _reportHeaderLanguage == language;
                    return ChoiceChip(
                      label: Text(language.label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _reportHeaderLanguage = language);
                      },
                      selectedColor: AppColors.primaryLight,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primaryTeal
                            : const Color(0xFFE3EAF2),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryTeal
                            : const Color(0xFF445166),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildResponsiveColumns(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('English Font'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _reportHeaderEnglishFontFamily,
                          items: _englishFontItems,
                          onChanged: (value) {
                            setState(() {
                              _reportHeaderEnglishFontFamily = value ?? '';
                            });
                          },
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Sinhala Font'),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _reportHeaderSinhalaFontFamily,
                          items: _sinhalaFontItems,
                          onChanged: (value) {
                            setState(() {
                              _reportHeaderSinhalaFontFamily =
                                  value ??
                                  ReportHeaderSettings
                                      .defaults
                                      .sinhalaFontFamily;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildResponsiveColumns(
                  spacing: 12,
                  children: [
                    _LabeledNumberField(
                      label: 'Top Margin',
                      controller: _reportHeaderTopMarginController,
                    ),
                    _LabeledNumberField(
                      label: 'Bottom Margin',
                      controller: _reportHeaderBottomMarginController,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildResponsiveActionRow(
                  leading: TextButton.icon(
                    onPressed: _resetReportHeaderDefaults,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Report Header'),
                  ),
                  trailing: Text(
                    'Preview updates the reports page header.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  child: Center(
                    child: ReportHeaderPreviewCard(
                      shopInfo: _shopInfo,
                      settings: _currentReportHeaderSettings,
                      fromDateLabel: 'Apr 01',
                      toDateLabel: 'Apr 30',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Application Name'),
          const SizedBox(height: 8),
          const _ReadOnlyField(value: 'Nexpos'),
          const SizedBox(height: 14),
          const _FieldLabel('Version'),
          const SizedBox(height: 8),
          const _ReadOnlyField(value: '1.0.0'),
          const SizedBox(height: 14),
          const _FieldLabel('Developer'),
          const SizedBox(height: 8),
          const _ReadOnlyField(value: 'Nexpos Team'),
          const SizedBox(height: 14),
          const _FieldLabel('Website'),
          const SizedBox(height: 8),
          const _ReadOnlyField(value: 'https://nexpos.com'),
          const SizedBox(height: 24),
          _SettingsBlock(
            title: 'Setup Information',
            child: Column(
              children: [
                _InfoRow(label: 'Shop Name', value: _shopInfo.shopName),
                _InfoRow(
                  label: 'Contact Email',
                  value: _shopInfo.contactEmail.isEmpty
                      ? '-'
                      : _shopInfo.contactEmail,
                ),
                _InfoRow(
                  label: 'Contact Number',
                  value: _shopInfo.contactNumber.isEmpty
                      ? '-'
                      : _shopInfo.contactNumber,
                ),
                _InfoRow(
                  label: 'Address',
                  value: _shopInfo.address.isEmpty ? '-' : _shopInfo.address,
                  expandValue: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.selectedSection, required this.onSelected});

  final _SettingsMenuSection selectedSection;
  final ValueChanged<_SettingsMenuSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 640 ? 16.0 : 20.0;
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SETTINGS MENU',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ..._SettingsMenuSection.values.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MenuItem(
                    section: section,
                    isSelected: section == selectedSection,
                    onTap: () => onSelected(section),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final _SettingsMenuSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              section.icon,
              size: 20,
              color: isSelected
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Text(
              section.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryTeal
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 640 ? 16.0 : 20.0;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EDF5)),
          ),
          child: child,
        );
      },
    );
  }
}

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 640 ? 14.0 : 18.0;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryTeal : const Color(0xFFE3EAF2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryTeal),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewInfoText extends StatelessWidget {
  const _PreviewInfoText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeStyleCard extends StatelessWidget {
  const _ThemeStyleCard({
    required this.title,
    required this.selected,
    required this.previewColor,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Color previewColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryTeal : const Color(0xFFE6EDF5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 82,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6EDF5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentColorOption extends StatelessWidget {
  const _AccentColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EDF5)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: value,
                        activeThumbColor: AppColors.white,
                        activeTrackColor: AppColors.primaryTeal,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    Switch(
                      value: value,
                      activeThumbColor: AppColors.white,
                      activeTrackColor: AppColors.primaryTeal,
                      onChanged: onChanged,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, this.suffixText});

  final TextEditingController controller;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        suffixText: suffixText,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
    );
  }
}

class _LabeledNumberField extends StatelessWidget {
  const _LabeledNumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _NumberField(controller: controller),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
      items: items,
    );
  }
}

class _ShortcutDropdownField extends StatelessWidget {
  const _ShortcutDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final PosShortcutKey value;
  final List<DropdownMenuItem<PosShortcutKey>> items;
  final ValueChanged<PosShortcutKey?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PosShortcutKey>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.6),
        ),
      ),
    );
  }
}

class _PrinterDropdownField extends StatelessWidget {
  const _PrinterDropdownField({
    required this.value,
    required this.selectedLabel,
    required this.printers,
    required this.hintText,
    required this.onChanged,
  });

  final String? value;
  final String selectedLabel;
  final List<Printer> printers;
  final String hintText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasMissingSelection =
        value != null &&
        value!.trim().isNotEmpty &&
        printers.every((printer) => printer.url != value);

    return DropdownButtonFormField<String>(
      initialValue: hasMissingSelection ? null : value,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(14),
      hint: Text(
        hasMissingSelection && selectedLabel.trim().isNotEmpty
            ? '$selectedLabel (Unavailable)'
            : hintText,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.6),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Use print dialog / system default'),
        ),
        ...printers.map(
          (printer) => DropdownMenuItem<String>(
            value: printer.url,
            child: Text(
              (printer.location ?? '').trim().isEmpty
                  ? printer.name
                  : '${printer.name} • ${printer.location}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.expandValue = false,
  });

  final String label;
  final String value;
  final bool expandValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        );
        final valueWidget = Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: constraints.maxWidth < 560
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelWidget,
                    const SizedBox(height: 4),
                    valueWidget,
                  ],
                )
              : Row(
                  crossAxisAlignment: expandValue
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 120, child: labelWidget),
                    Expanded(child: valueWidget),
                  ],
                ),
        );
      },
    );
  }
}
