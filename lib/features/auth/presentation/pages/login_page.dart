import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/pin_number_pad.dart';
import '../../../activation/services/activation_service.dart';
import '../../../backup/services/backup_service.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../setup/services/setup_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isBootLoading = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  LoginMethod _loginMethod = LoginMethod.emailPassword;
  String _adminEmail = '';

  @override
  void initState() {
    super.initState();
    _loadSetupState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSetupState() async {
    final setupState = await SetupService.instance.loadState();
    if (!mounted) {
      return;
    }

    setState(() {
      _isBootLoading = false;
      _loginMethod = setupState.defaultLoginMethod ?? LoginMethod.emailPassword;
      _adminEmail = setupState.adminEmail;
      if (_adminEmail.isNotEmpty && _loginMethod == LoginMethod.emailPassword) {
        _usernameController.text = _adminEmail;
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_loginMethod == LoginMethod.pin) {
      await _handlePinLogin();
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppToast.error('Please fill in your username and password');
      return;
    }

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) {
      return;
    }

    final isAuthorized = await SetupService.instance.validateAdminCredentials(
      email: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!isAuthorized) {
      AppToast.error('Invalid username or password');
      return;
    }

    await _openDashboard();
  }

  Future<void> _handlePinLogin() async {
    if (_pinController.text.length != 4) {
      AppToast.error('Enter your 4 digit PIN');
      return;
    }

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final isAuthorized = await SetupService.instance.validatePin(
      _pinController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (!isAuthorized) {
      AppToast.error('Invalid PIN');
      return;
    }

    await _openDashboard();
  }

  Future<void> _openDashboard() async {
    try {
      final automaticBackup = await BackupService.instance
          .createBackupIfEnabled();
      if (automaticBackup != null) {
        AppToast.info('Automatic login backup created');
      }
    } catch (error) {
      AppToast.error('Login backup failed: $error');
    }

    if (!mounted) {
      return;
    }

    AppToast.success('Login successful');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
    );
  }

  void _handleForgotPassword() {
    AppToast.info('Use the setup flow to change the admin account for now');
  }

  void _handleContactAdmin() {
    AppToast.info('Administrator contact flow will be added next');
  }

  Future<void> _handleDeleteActivation() async {
    await ActivationService.instance.clearActivation();

    if (!mounted) {
      return;
    }

    AppToast.info('Stored activation removed');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _handleResetSetup() async {
    await SetupService.instance.resetSetup();

    if (!mounted) {
      return;
    }

    AppToast.info('Stored setup information removed');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isBootLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        color: const Color(0xFFFBFCFE),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.97, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Container(
                      width: 380,
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFE5EAF1)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'NexPos',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF313D4F),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _loginMethod == LoginMethod.pin
                                  ? 'PIN Access'
                                  : 'Point of Sale System',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF8E9BB0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (_loginMethod == LoginMethod.emailPassword)
                              _buildPasswordLogin(textTheme)
                            else
                              _buildPinLogin(textTheme),
                            const SizedBox(height: 18),
                            LoginButton(
                              label: _loginMethod == LoginMethod.pin
                                  ? 'Login With PIN'
                                  : 'Login',
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleLogin,
                            ),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF4C8FE8),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 20),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Divider(
                              color: Color(0xFFEEF2F7),
                              thickness: 1,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    color: const Color(0xFF8A98AB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                InkWell(
                                  onTap: _handleContactAdmin,
                                  child: Text(
                                    'Contact Admin',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      color: const Color(0xFF4C8FE8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: _handleResetSetup,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFDD8C1A),
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 20),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.restart_alt_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Reset Setup Info',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFDD8C1A),
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _handleDeleteActivation,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFE25C5C),
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 20),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Delete Activation Info',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE25C5C),
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
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '© 2026 NexPos POS System. All rights reserved.',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBAC5D3),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordLogin(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _usernameController,
          label: 'Username / Email',
          hintText: 'Enter your username or email',
          autofocus: true,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Username or email is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'Enter your password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
                side: const BorderSide(color: Color(0xFFD8DFEA)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Remember Me',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: const Color(0xFF8A98AB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinLogin(TextTheme textTheme) {
    final baseTheme = PinTheme(
      width: 58,
      height: 58,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
    );

    return Column(
      children: [
        if (_adminEmail.isNotEmpty)
          Text(
            _adminEmail,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8E9BB0),
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        Pinput(
          controller: _pinController,
          focusNode: _pinFocusNode,
          length: 4,
          autofocus: true,
          keyboardType: TextInputType.number,
          defaultPinTheme: baseTheme,
          focusedPinTheme: baseTheme.copyWith(
            decoration: baseTheme.decoration!.copyWith(
              border: Border.all(color: const Color(0xFF36B4AE), width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 18),
        PinNumberPad(
          enabled: !_isLoading,
          onDigitPressed: _appendPinDigit,
          onBackspace: _removePinDigit,
        ),
      ],
    );
  }
}
