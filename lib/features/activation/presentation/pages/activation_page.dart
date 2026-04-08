import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../services/activation_service.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({
    super.key,
    required this.deviceId,
    required this.onActivated,
  });

  final String deviceId;
  final VoidCallback onActivated;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _keyController = TextEditingController();
  bool _isActivating = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: widget.deviceId));
    AppToast.success('Device ID copied');
  }

  Future<void> _activate() async {
    if (_keyController.text.trim().isEmpty) {
      AppToast.error('Enter the activation key');
      return;
    }

    setState(() => _isActivating = true);
    final isActivated = await ActivationService.instance.activate(
      _keyController.text.trim(),
    );
    if (!mounted) {
      return;
    }

    setState(() => _isActivating = false);

    if (!isActivated) {
      AppToast.error('Invalid activation key');
      return;
    }

    AppToast.success('Application activated successfully');
    widget.onActivated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: Center(
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8EDF4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activate NexPos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F3B4E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'First-time activation is required before you can sign in. Copy the device ID, enter the activation key, and activate this installation.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7F8DA1),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Device ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF465366),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4EAF2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        widget.deviceId,
                        style: const TextStyle(
                          fontSize: 18,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _copyDeviceId,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 44),
                        side: const BorderSide(color: Color(0xFFD8E2EE)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Activation Key',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF465366),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter activation key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primaryTeal,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActivating ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF36B4AE),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Activate',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
