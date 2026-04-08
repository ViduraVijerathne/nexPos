import 'package:flutter/material.dart';

import 'features/activation/presentation/pages/activation_page.dart';
import 'features/activation/services/activation_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/setup/presentation/pages/setup_page.dart';
import 'features/setup/services/setup_service.dart';

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  bool _isLoading = true;
  bool _isActivated = false;
  bool _isSetupComplete = false;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadBootState();
  }

  Future<void> _loadBootState() async {
    final activationState = await ActivationService.instance.loadState();
    final setupState = await SetupService.instance.loadState();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isActivated = activationState.isActivated;
      _isSetupComplete = setupState.isComplete;
      _deviceId = activationState.deviceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isActivated) {
      return ActivationPage(deviceId: _deviceId, onActivated: _loadBootState);
    }

    if (!_isSetupComplete) {
      return SetupPage(onCompleted: _loadBootState);
    }

    return const LoginPage();
  }
}
