import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/toast/app_toast_overlay.dart';
import 'features/activation/presentation/pages/activation_page.dart';
import 'features/activation/services/activation_service.dart';
import 'features/auth/presentation/pages/login_page.dart';

class NexPosApp extends StatelessWidget {
  const NexPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nex POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: AppToastOverlay.navigatorKey,
      builder: (context, child) {
        return AppToastOverlay(child: child ?? const SizedBox.shrink());
      },
      home: const _AppBootstrapPage(),
    );
  }
}

class _AppBootstrapPage extends StatefulWidget {
  const _AppBootstrapPage();

  @override
  State<_AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<_AppBootstrapPage> {
  bool _isLoading = true;
  bool _isActivated = false;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadBootState();
  }

  Future<void> _loadBootState() async {
    final state = await ActivationService.instance.loadState();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isActivated = state.isActivated;
      _deviceId = state.deviceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isActivated) {
      return ActivationPage(
        deviceId: _deviceId,
        onActivated: () {
          setState(() => _isActivated = true);
        },
      );
    }

    return const LoginPage();
  }
}
