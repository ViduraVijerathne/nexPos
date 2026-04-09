import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../settings/services/app_settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _taxPercentController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTaxEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _taxPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AppSettingsService.instance.loadPosTaxSettings();
      if (!mounted) {
        return;
      }

      setState(() {
        _isTaxEnabled = settings.isTaxEnabled;
        _taxPercentController.text = _formatTaxPercent(settings.taxPercent);
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
    if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
      AppToast.error('Enter a valid tax percentage between 0 and 100');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AppSettingsService.instance.savePosTaxSettings(
        isTaxEnabled: _isTaxEnabled,
        taxPercent: taxPercent,
      );
      if (!mounted) {
        return;
      }
      AppToast.success('POS tax settings saved');
    } catch (error) {
      AppToast.error('Failed to save settings: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatTaxPercent(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

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
                  'Configure POS behavior and business rules.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8090A4),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 760,
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
                      const Text(
                        'POS Tax Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334156),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable or disable tax in the POS screen and change the tax percentage used during billing.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A98AD),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
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
                                  const Text(
                                    'Show Tax In POS',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334156),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isTaxEnabled
                                        ? 'Tax row and tax amount are enabled in the billing summary.'
                                        : 'Tax is hidden by default until you enable it.',
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
                              value: _isTaxEnabled,
                              activeColor: AppColors.primaryTeal,
                              onChanged: (value) {
                                setState(() => _isTaxEnabled = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tax Percentage',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A586B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: _taxPercentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '10',
                            suffixText: '%',
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAF2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EAF2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryTeal,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          child: Text(
                            _isSaving ? 'Saving...' : 'Save Settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
