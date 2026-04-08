import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
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

  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppToast.error('Please fill in your username and password');
      return;
    }

    setState(() => _isLoading = true);

    // Simulated auth keeps the screen interactive while the real backend is pending.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    if (!mounted) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final isAuthorized = username == 'admin' && password == 'admin123';

    setState(() => _isLoading = false);

    if (!isAuthorized) {
      AppToast.error('Invalid username or password');
      return;
    }

    AppToast.success('Login successful');

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
    );
  }

  void _handleForgotPassword() {
    AppToast.info('Please contact your administrator to reset the password');
  }

  void _handleContactAdmin() {
    AppToast.info('Administrator contact flow will be added next');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        color: const Color(0xFFFBFCFE),
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
                width: 360,
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
                        'Point of Sale System',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF8E9BB0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
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
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                      const SizedBox(height: 18),
                      LoginButton(
                        label: 'Login',
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
                      const Divider(color: Color(0xFFEEF2F7), thickness: 1),
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
    );
  }
}
