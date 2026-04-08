import 'package:flutter/material.dart';

import 'app_bootstrap_page.dart';
import 'core/theme/app_theme.dart';
import 'core/toast/app_toast_overlay.dart';

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
      home: const AppBootstrapPage(),
    );
  }
}
