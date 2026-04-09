import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';

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
        _marginTopController.text = _formatNumber(invoiceSettings.marginTop);
        _marginRightController.text = _formatNumber(
          invoiceSettings.marginRight,
        );
        _marginBottomController.text = _formatNumber(
          invoiceSettings.marginBottom,
        );
        _marginLeftController.text = _formatNumber(invoiceSettings.marginLeft);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : SingleChildScrollView(
              child: Column(
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
                    'Configure POS behavior, customer flow, and invoice printing.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8090A4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'POS Tax Settings',
                    description:
                        'Enable or disable tax in the POS screen and change the tax percentage used during billing.',
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
                          width: 240,
                          child: _NumberField(
                            controller: _taxPercentController,
                            suffixText: '%',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsSection(
                    title: 'POS Customer Flow',
                    description:
                        'Control how POS creates a new customer during checkout when the typed mobile number is not already in the database.',
                    child: _SwitchTile(
                      title: 'Create Customer Only Contact Number',
                      description: _createCustomerOnlyContact
                          ? 'When POS needs a new customer, the entered mobile number alone will be used to create it.'
                          : 'When POS needs a new customer, a full customer creation dialog will be shown.',
                      value: _createCustomerOnlyContact,
                      onChanged: (value) {
                        setState(() => _createCustomerOnlyContact = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsSection(
                    title: 'Invoice Layout Designer',
                    description:
                        'Create your own invoice design for 80mm thermal or A4 printing with layout, language, font, and margin controls.',
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
                                  right: size == InvoicePaperSize.thermal80mm
                                      ? 12
                                      : 0,
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _paperSize = size),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFE8FBF7)
                                          : AppColors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primaryTeal
                                            : const Color(0xFFE3EAF2),
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          size == InvoicePaperSize.thermal80mm
                                              ? Icons.receipt_long_outlined
                                              : Icons.description_outlined,
                                          color: AppColors.primaryTeal,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          size.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334156),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Invoice Language'),
                        const SizedBox(height: 10),
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
                                      setState(() {
                                        _englishFontFamily = value ?? '';
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
                        const SizedBox(height: 18),
                        const _FieldLabel('Printing Margins'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledNumberField(
                                label: 'Top',
                                controller: _marginTopController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledNumberField(
                                label: 'Right',
                                controller: _marginRightController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledNumberField(
                                label: 'Bottom',
                                controller: _marginBottomController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledNumberField(
                                label: 'Left',
                                controller: _marginLeftController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
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
                        const SizedBox(height: 20),
                        const Text(
                          'Live Invoice Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334156),
                          ),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      child: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A98AD),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
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
        color: const Color(0xFFF8FBFD),
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
