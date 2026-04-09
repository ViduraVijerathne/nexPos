import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  runApp(const NexPosApp());
}
