import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../../../core/widgets/report_header_preview.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';

enum _SettingsMenuSection {
  profile,
  notifications,
  security,
  languageRegion,
  systemPreferences,
  systemUpdates,
  about,
}

extension on _SettingsMenuSection {
  String get title => switch (this) {
    _SettingsMenuSection.profile => 'Profile Settings',
    _SettingsMenuSection.notifications => 'Notifications',
    _SettingsMenuSection.security => 'Security',
    _SettingsMenuSection.languageRegion => 'Invoice Layout',
    _SettingsMenuSection.systemPreferences => 'System Preferences',
    _SettingsMenuSection.systemUpdates => 'System Updates',
    _SettingsMenuSection.about => 'About',
  };

  IconData get icon => switch (this) {
    _SettingsMenuSection.profile => Icons.person_outline_rounded,
    _SettingsMenuSection.notifications => Icons.notifications_none_rounded,
    _SettingsMenuSection.security => Icons.lock_outline_rounded,
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

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTaxEnabled = false;
  bool _createCustomerOnlyContact = false;
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final taxSettings = await AppSettingsService.instance
          .loadPosTaxSettings();
      final customerSettings = await AppSettingsService.instance
          .loadPosCustomerSettings();
      final invoiceSettings = await AppSettingsService.instance
          .loadInvoiceLayoutSettings();
      final reportHeaderSettings = await AppSettingsService.instance
          .loadReportHeaderSettings();
      final setupState = await SetupService.instance.loadState();

      if (!mounted) {
        return;
      }

      setState(() {
        _isTaxEnabled = taxSettings.isTaxEnabled;
        _taxPercentController.text = _formatNumber(taxSettings.taxPercent);
        _createCustomerOnlyContact = customerSettings.createCustomerOnlyContact;
        _shopInfo = setupState.shopInfo;
        _paperSize = invoiceSettings.paperSize;
        _invoiceLanguage = invoiceSettings.language;
        _englishFontFamily = invoiceSettings.englishFontFamily;
        _sinhalaFontFamily = invoiceSettings.sinhalaFontFamily;
        _reportHeaderLanguage = reportHeaderSettings.language;
        _reportHeaderEnglishFontFamily = reportHeaderSettings.englishFontFamily;
        _reportHeaderSinhalaFontFamily = reportHeaderSettings.sinhalaFontFamily;
        _showReportLogo = reportHeaderSettings.showLogo;
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

    if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
      AppToast.error('Enter a valid tax percentage between 0 and 100');
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
    tax: 0,
    total: 2500,
    paymentMethod: 'Cash',
    paidAmount: 3000,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3A4D),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage your system preferences and configurations.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8090A4),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 375,
                        child: _MenuCard(
                          selectedSection: _selectedSection,
                          onSelected: (section) {
                            setState(() => _selectedSection = section);
                          },
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _ContentCard(
                          child: _buildSelectedSectionContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedSectionContent() {
    return switch (_selectedSection) {
      _SettingsMenuSection.profile => _buildProfileSection(),
      _SettingsMenuSection.notifications => _InfoPanel(
        title: 'Notifications',
        description:
            'Email alerts, low-stock notifications, and reminder controls are reserved for the upcoming notification module.',
        icon: Icons.notifications_none_rounded,
      ),
      _SettingsMenuSection.security => _InfoPanel(
        title: 'Security',
        description:
            'PIN policy, password rules, and access controls will be managed from this section as backend security options expand.',
        icon: Icons.lock_outline_rounded,
      ),
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
          const Text(
            'System Preferences',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
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
          const Text(
            'Profile Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsBlock(
            title: 'Shop Preview',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 104,
                  width: 104,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8FC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE6EDF5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasLogo
                      ? Image.file(File(_shopInfo.logoPath), fit: BoxFit.cover)
                      : const Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: Color(0xFF8AA0B8),
                        ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shopInfo.shopName.trim().isEmpty
                            ? 'Shop name not set'
                            : _shopInfo.shopName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334156),
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
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickShopLogo,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Change Logo'),
                ),
              ],
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
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

  Widget _buildLanguageRegionSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Layout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
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
                      selectedColor: const Color(0xFFE8FBF7),
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
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
                Row(
                  children: InvoicePaperSize.values.map((size) {
                    final selected = _paperSize == size;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: size == InvoicePaperSize.thermal80mm ? 12 : 0,
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
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Top Margin',
                        controller: _marginTopController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Right Margin',
                        controller: _marginRightController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Bottom Margin',
                        controller: _marginBottomController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Left Margin',
                        controller: _marginLeftController,
                      ),
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
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _resetInvoiceLayoutDefaults,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Default Layout'),
                    ),
                    const Spacer(),
                    const Text(
                      'Shop logo and title come from setup information.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A98AD),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
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
                      selectedColor: const Color(0xFFE8FBF7),
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
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
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Top Margin',
                        controller: _reportHeaderTopMarginController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledNumberField(
                        label: 'Bottom Margin',
                        controller: _reportHeaderBottomMarginController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _resetReportHeaderDefaults,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Report Header'),
                    ),
                    const Spacer(),
                    const Text(
                      'Preview updates the reports page header.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A98AD),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
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
          const Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETTINGS MENU',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8594AA),
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
          color: isSelected ? const Color(0xFFD9F7F3) : Colors.transparent,
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
                  : const Color(0xFF71829B),
            ),
            const SizedBox(width: 14),
            Text(
              section.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryTeal
                    : const Color(0xFF4A586B),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: child,
    );
  }
}

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
          color: selected ? const Color(0xFFE8FBF7) : AppColors.white,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334156),
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
                color: const Color(0xFFE8FBF7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334156),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8090A4),
                height: 1.6,
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334156),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A98AD),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primaryTeal,
            onChanged: onChanged,
          ),
        ],
      ),
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
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4A586B),
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
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
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
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
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
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
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
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6E7E94),
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
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
      items: items,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: expandValue
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E7E94),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334156),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
