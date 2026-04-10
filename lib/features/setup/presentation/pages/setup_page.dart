import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/pin_number_pad.dart';
import '../../../../core/widgets/selection_option_card.dart';
import '../../../online/services/online_firebase_service.dart';
import '../../services/setup_service.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopEmailController = TextEditingController();
  final TextEditingController _shopPhoneController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  AppMode? _selectedMode;
  LoginMethod? _selectedLoginMethod;
  String _savedLogoPath = '';
  String _firstPinEntry = '';
  String _savedPinValue = '';
  bool _isConfirmingPin = false;
  bool _isShopLookupLoading = false;
  bool _hasExistingOnlineShop = false;
  String _resolvedOnlineShopId = '';

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    _shopEmailController.dispose();
    _shopPhoneController.dispose();
    _shopAddressController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    final state = await SetupService.instance.loadState();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMode = state.mode;
      _selectedLoginMethod = state.defaultLoginMethod;
      _savedLogoPath = state.shopInfo.logoPath;
      _savedPinValue = state.pin;
      _resolvedOnlineShopId = state.selectedShopId;
      _hasExistingOnlineShop =
          state.mode == AppMode.online &&
          state.selectedShopId.trim().isNotEmpty;
      _adminEmailController.text = state.adminEmail;
      _shopNameController.text = state.shopInfo.shopName;
      _shopEmailController.text = state.shopInfo.contactEmail;
      _shopPhoneController.text = state.shopInfo.contactNumber;
      _shopAddressController.text = state.shopInfo.address;
      _currentStep = state.firstIncompleteStep;
      _isLoading = false;
    });
  }

  Future<void> _saveMode() async {
    if (_selectedMode == null) {
      AppToast.error('Select a version to continue');
      return;
    }

    await SetupService.instance.saveAppMode(_selectedMode!);
    _goToStep(1);
  }

  Future<void> _saveAdminAccount() async {
    final email = _adminEmailController.text.trim();
    final password = _adminPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppToast.error('Fill all admin account fields');
      return;
    }
    if (_selectedMode != AppMode.online && confirmPassword.isEmpty) {
      AppToast.error('Fill all admin account fields');
      return;
    }
    if (_selectedMode != AppMode.online && password != confirmPassword) {
      AppToast.error('Passwords do not match');
      return;
    }
    if (password.length < 4) {
      AppToast.error('Password should be at least 4 characters');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_selectedMode == AppMode.online) {
        await OnlineFirebaseService.instance.verifyAdminCredentials(
          email: email,
          password: password,
        );
      }

      await SetupService.instance.saveAdminAccount(
        email: email,
        password: password,
      );
      _goToStep(_pinStepIndex);
      if (_selectedMode == AppMode.online) {
        AppToast.success('Admin account login verified');
      }
    } catch (error) {
      AppToast.error(_buildOnlineAdminErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _buildOnlineAdminErrorMessage(Object error) {
    final raw = error.toString();
    final cleaned = raw
        .replaceFirst('firebase_auth/', '')
        .replaceFirst('Exception: ', '')
        .trim();

    if (cleaned.isEmpty) {
      return 'Unable to login with the provided admin account';
    }

    return 'Admin login failed: $cleaned';
  }

  Future<void> _savePin() async {
    if (_firstPinEntry.length != 4 || _pinController.text.length != 4) {
      AppToast.error('Enter a 4 digit PIN');
      return;
    }
    if (_firstPinEntry != _pinController.text) {
      AppToast.error('PIN confirmation does not match');
      return;
    }

    _savedPinValue = _pinController.text;
    await SetupService.instance.savePin(_savedPinValue);
    setState(() {
      _pinController.clear();
      _firstPinEntry = '';
      _isConfirmingPin = false;
    });
    _goToStep(_loginMethodStepIndex);
  }

  Future<void> _saveLoginMethod() async {
    if (_selectedLoginMethod == null) {
      AppToast.error('Select a default login way');
      return;
    }

    await SetupService.instance.saveDefaultLoginMethod(_selectedLoginMethod!);
    if (_selectedMode == AppMode.online &&
        _selectedLoginMethod == LoginMethod.pin) {
      await SetupService.instance.saveOnlinePinCredentials(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text.trim(),
        pin: _savedPinValue,
      );
    } else {
      await SetupService.instance.clearOnlinePinCredentials();
    }
    if (_selectedMode == AppMode.online) {
      await _loadOnlineShopInfo();
    }
    _goToStep(_shopInfoStepIndex);
  }

  Future<void> _loadOnlineShopInfo() async {
    final adminEmail = _adminEmailController.text.trim();
    if (_selectedMode != AppMode.online || adminEmail.isEmpty) {
      return;
    }

    setState(() => _isShopLookupLoading = true);
    try {
      final shop = await OnlineFirebaseService.instance.findShopByAdminEmail(
        adminEmail,
      );
      if (!mounted) {
        return;
      }

      if (shop == null) {
        setState(() {
          _hasExistingOnlineShop = false;
          _resolvedOnlineShopId = '';
        });
        return;
      }

      await SetupService.instance.saveShopInfo(shop.shopInfo, shopId: shop.id);

      setState(() {
        _hasExistingOnlineShop = true;
        _resolvedOnlineShopId = shop.id;
        _savedLogoPath = shop.shopInfo.logoPath;
        _shopNameController.text = shop.shopInfo.shopName;
        _shopEmailController.text = shop.shopInfo.contactEmail;
        _shopPhoneController.text = shop.shopInfo.contactNumber;
        _shopAddressController.text = shop.shopInfo.address;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error('Failed to load shop information: $error');
    } finally {
      if (mounted) {
        setState(() => _isShopLookupLoading = false);
      }
    }
  }

  Future<void> _pickLogo() async {
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

    setState(() => _savedLogoPath = savedPath);
    AppToast.success('Shop logo selected');
  }

  Future<void> _saveShopInfo() async {
    if (_shopNameController.text.trim().isEmpty) {
      AppToast.error('Shop name is required');
      return;
    }

    final shopInfo = ShopInfo(
      logoPath: _savedLogoPath,
      shopName: _shopNameController.text.trim(),
      contactEmail: _shopEmailController.text.trim(),
      contactNumber: _shopPhoneController.text.trim(),
      address: _shopAddressController.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      if (_selectedMode == AppMode.online) {
        if (_hasExistingOnlineShop && _resolvedOnlineShopId.isNotEmpty) {
          await SetupService.instance.saveShopInfo(
            shopInfo,
            shopId: _resolvedOnlineShopId,
          );
        } else {
          final created = await OnlineFirebaseService.instance
              .createShopForAdmin(
                adminEmail: _adminEmailController.text.trim(),
                shopInfo: shopInfo,
              );
          _resolvedOnlineShopId = created.id;
          _hasExistingOnlineShop = true;
          await SetupService.instance.saveShopInfo(
            created.shopInfo,
            shopId: created.id,
          );
        }
      } else {
        await SetupService.instance.saveShopInfo(shopInfo);
      }

      _goToStep(_successStepIndex);
    } catch (error) {
      AppToast.error('Unable to save shop information: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _appendPinDigit(String digit) {
    if (_pinController.text.length >= 4) {
      return;
    }
    setState(() {
      _pinController.text = '${_pinController.text}$digit';
    });
  }

  void _removePinDigit() {
    if (_pinController.text.isEmpty) {
      return;
    }
    setState(() {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
    });
  }

  void _handlePinChanged(String value) {
    if (value.length != 4) {
      return;
    }

    if (!_isConfirmingPin) {
      setState(() {
        _firstPinEntry = value;
        _isConfirmingPin = true;
        _pinController.clear();
      });
      AppToast.info('Confirm the same 4 digit PIN');
      return;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _VersionSelectionStep(
          selectedMode: _selectedMode,
          onModeChanged: (mode) => setState(() => _selectedMode = mode),
          onNext: _saveMode,
        );
      case 1:
        return _AdminAccountStep(
          emailController: _adminEmailController,
          passwordController: _adminPasswordController,
          confirmPasswordController: _confirmPasswordController,
          onBack: () => _goToStep(0),
          onCreate: _saveAdminAccount,
          isOnlineMode: _selectedMode == AppMode.online,
          isSaving: _isSaving,
        );
      case 2:
        return _PinSetupStep(
          pinController: _pinController,
          pinFocusNode: _pinFocusNode,
          isConfirming: _isConfirmingPin,
          onChanged: _handlePinChanged,
          onDigitPressed: _appendPinDigit,
          onBackspace: _removePinDigit,
          onBack: () => _goToStep(_adminAccountStepIndex),
          onSave: _savePin,
        );
      case 3:
        return _LoginMethodStep(
          selectedMethod: _selectedLoginMethod,
          onMethodChanged: (method) =>
              setState(() => _selectedLoginMethod = method),
          onBack: () => _goToStep(_pinStepIndex),
          onNext: _saveLoginMethod,
          isOnlineMode: _selectedMode == AppMode.online,
        );
      case 4:
        return _ShopInformationStep(
          logoPath: _savedLogoPath,
          shopNameController: _shopNameController,
          emailController: _shopEmailController,
          phoneController: _shopPhoneController,
          addressController: _shopAddressController,
          onPickLogo: _pickLogo,
          onBack: () => _goToStep(_loginMethodStepIndex),
          onSave: _saveShopInfo,
          isOnlineMode: _selectedMode == AppMode.online,
          isExistingOnlineShop: _hasExistingOnlineShop,
          isLookupLoading: _isShopLookupLoading,
          isSaving: _isSaving,
        );
      default:
        return _SuccessStep(onFinish: widget.onCompleted);
    }
  }

  int get _adminAccountStepIndex => 1;
  int get _pinStepIndex => 2;
  int get _loginMethodStepIndex => 3;
  int get _shopInfoStepIndex => 4;
  int get _successStepIndex => 5;
  int get _totalSteps => 6;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 760,
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
              child: IgnorePointer(
                ignoring: _isSaving,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stepTitle(_currentStep),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2F3B4E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepSubtitle(_currentStep),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7F8DA1),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SetupProgress(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                    ),
                    const SizedBox(height: 28),
                    _buildStepContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle(int step) => switch (step) {
    0 => 'Choose Your Version',
    1 => 'Create Admin Account',
    2 => 'Set Login PIN',
    3 => 'Default Login Method',
    4 => 'Shop Information',
    _ => 'Setup Complete',
  };

  String _stepSubtitle(int step) => switch (step) {
    0 => 'Select how you want this installation to run.',
    1 => 'This account will be used to access the admin dashboard.',
    2 => 'Create a 4 digit PIN for fast secure access.',
    3 => 'Choose which login method should appear by default.',
    4 => 'Add the business details shown throughout the app.',
    _ => 'Your store is ready. Continue to the login screen.',
  };
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF36B4AE)
                  : const Color(0xFFE6ECF4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _VersionSelectionStep extends StatelessWidget {
  const _VersionSelectionStep({
    required this.selectedMode,
    required this.onModeChanged,
    required this.onNext,
  });

  final AppMode? selectedMode;
  final ValueChanged<AppMode> onModeChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectionOptionCard<AppMode>(
          value: AppMode.online,
          groupValue: selectedMode,
          title: 'Online Version',
          description: 'Cloud-connected mode with centralized syncing.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5FBF7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Firebase',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF159F92),
              ),
            ),
          ),
          onTap: () => onModeChanged(AppMode.online),
        ),
        const SizedBox(height: 14),
        SelectionOptionCard<AppMode>(
          value: AppMode.offline,
          groupValue: selectedMode,
          title: 'Offline Version',
          description:
              'Local-first mode for desktop operation without online sync.',
          onTap: () => onModeChanged(AppMode.offline),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: selectedMode == null ? null : onNext,
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }
}

class _AdminAccountStep extends StatelessWidget {
  const _AdminAccountStep({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onBack,
    required this.onCreate,
    required this.isOnlineMode,
    required this.isSaving,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final bool isOnlineMode;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SetupTextField(
          controller: emailController,
          label: isOnlineMode ? 'Login Admin Email' : 'Admin Email',
          hintText: 'admin@example.com',
          prefixIcon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 16),
        _SetupTextField(
          controller: passwordController,
          label: 'Password',
          hintText: 'Enter password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        if (isOnlineMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4F2E7)),
            ),
            child: const Text(
              'Enter the admin account already created by the developer. The app will try to sign in and only continue if the login is successful.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E6E59),
                height: 1.5,
              ),
            ),
          ),
        if (isOnlineMode) const SizedBox(height: 16),
        if (!isOnlineMode)
          _SetupTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hintText: 'Re-enter password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isSaving ? null : onCreate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(170, 48)),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isOnlineMode
                          ? 'Verify & Continue'
                          : 'Create Admin Account',
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinSetupStep extends StatelessWidget {
  const _PinSetupStep({
    required this.pinController,
    required this.pinFocusNode,
    required this.isConfirming,
    required this.onChanged,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onBack,
    required this.onSave,
  });

  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final bool isConfirming;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 62,
      height: 62,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
    );

    return Column(
      children: [
        Text(
          isConfirming ? 'Confirm the same 4 digit PIN' : 'Enter a 4 digit PIN',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 18),
        Pinput(
          controller: pinController,
          focusNode: pinFocusNode,
          length: 4,
          autofocus: true,
          keyboardType: TextInputType.number,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: const Color(0xFF36B4AE), width: 1.8),
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 26),
        PinNumberPad(onDigitPressed: onDigitPressed, onBackspace: onBackspace),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginMethodStep extends StatelessWidget {
  const _LoginMethodStep({
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.onBack,
    required this.onNext,
    required this.isOnlineMode,
  });

  final LoginMethod? selectedMethod;
  final ValueChanged<LoginMethod> onMethodChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isOnlineMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectionOptionCard<LoginMethod>(
          value: LoginMethod.emailPassword,
          groupValue: selectedMethod,
          title: 'Email & Password',
          description: 'Use the admin email and password on the login screen.',
          onTap: () => onMethodChanged(LoginMethod.emailPassword),
        ),
        const SizedBox(height: 14),
        SelectionOptionCard<LoginMethod>(
          value: LoginMethod.pin,
          groupValue: selectedMethod,
          title: 'PIN',
          description: isOnlineMode
              ? 'Use a 4 digit PIN. The app will decrypt saved Firebase credentials with the PIN and then authenticate online.'
              : 'Use a 4 digit PIN with keypad support for faster access.',
          onTap: () => onMethodChanged(LoginMethod.pin),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: selectedMethod == null ? null : onNext,
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShopInformationStep extends StatelessWidget {
  const _ShopInformationStep({
    required this.logoPath,
    required this.shopNameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.onPickLogo,
    required this.onBack,
    required this.onSave,
    required this.isOnlineMode,
    required this.isExistingOnlineShop,
    required this.isLookupLoading,
    required this.isSaving,
  });

  final String logoPath;
  final TextEditingController shopNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final VoidCallback onPickLogo;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool isOnlineMode;
  final bool isExistingOnlineShop;
  final bool isLookupLoading;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoPath.isNotEmpty && File(logoPath).existsSync();
    final isReadOnly = isOnlineMode && isExistingOnlineShop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOnlineMode)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EAF2)),
            ),
            child: isLookupLoading
                ? const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Checking existing shop for this admin account...',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF607086),
                        ),
                      ),
                    ],
                  )
                : Text(
                    isExistingOnlineShop
                        ? 'An existing shop was found for this admin account. Review the details below and continue.'
                        : 'No shop was found for this admin account. Register a new shop below.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isExistingOnlineShop
                          ? const Color(0xFF2E6E59)
                          : const Color(0xFF607086),
                      height: 1.5,
                    ),
                  ),
          ),
        const Text(
          'Shop Logo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF465366),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4EAF2)),
              ),
              child: hasLogo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(logoPath), fit: BoxFit.cover),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      color: Color(0xFFB0BBCB),
                      size: 34,
                    ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: isReadOnly || isLookupLoading ? null : onPickLogo,
              style: OutlinedButton.styleFrom(minimumSize: const Size(144, 48)),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(isReadOnly ? 'Existing Logo' : 'Select Logo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SetupTextField(
          controller: shopNameController,
          label: 'Shop Name *',
          hintText: 'Enter shop name',
          prefixIcon: Icons.storefront_outlined,
          readOnly: isReadOnly || isLookupLoading,
        ),
        const SizedBox(height: 16),
        _SetupTextField(
          controller: emailController,
          label: 'Contact Email',
          hintText: 'shop@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          readOnly: isReadOnly || isLookupLoading,
        ),
        const SizedBox(height: 16),
        _SetupTextField(
          controller: phoneController,
          label: 'Contact Number',
          hintText: '+94 77 123 4567',
          prefixIcon: Icons.call_outlined,
          readOnly: isReadOnly || isLookupLoading,
        ),
        const SizedBox(height: 16),
        _SetupTextField(
          controller: addressController,
          label: 'Address',
          hintText: 'Enter business address',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 3,
          readOnly: isReadOnly || isLookupLoading,
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isLookupLoading || isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(isExistingOnlineShop ? 'Continue' : 'Register Shop'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Color(0xFFE7FCF8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 48,
            color: Color(0xFF36B4AE),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Setup completed successfully',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your business configuration has been saved. Continue to the login screen to start using the app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7F8DA1),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onFinish,
          style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
          child: const Text('Go To Login'),
        ),
      ],
    );
  }
}

class _SetupTextField extends StatelessWidget {
  const _SetupTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF465366),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
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
              borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
