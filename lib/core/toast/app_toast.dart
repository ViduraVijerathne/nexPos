import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppToastType { success, error, info }

class AppToastData {
  AppToastData({
    required this.id,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
  });

  final String id;
  final String message;
  final AppToastType type;
  final Duration duration;
}

class AppToast {
  AppToast._();

  static final ValueNotifier<List<AppToastData>> _toasts =
      ValueNotifier<List<AppToastData>>(<AppToastData>[]);

  static ValueNotifier<List<AppToastData>> get listenable => _toasts;

  static void success(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(message: message, type: AppToastType.success, duration: duration);
  }

  static void error(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(message: message, type: AppToastType.error, duration: duration);
  }

  static void info(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(message: message, type: AppToastType.info, duration: duration);
  }

  static void dismiss(String id) {
    _toasts.value = _toasts.value.where((toast) => toast.id != id).toList();
  }

  static void _show({
    required String message,
    required AppToastType type,
    required Duration duration,
  }) {
    final toast = AppToastData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      type: type,
      duration: duration,
    );

    _toasts.value = List<AppToastData>.from(_toasts.value)..add(toast);
  }
}

extension AppToastTypeX on AppToastType {
  Color get accentColor {
    switch (this) {
      case AppToastType.success:
        return AppColors.success;
      case AppToastType.error:
        return AppColors.error;
      case AppToastType.info:
        return AppColors.info;
    }
  }

  IconData get icon {
    switch (this) {
      case AppToastType.success:
        return Icons.check_circle;
      case AppToastType.error:
        return Icons.error;
      case AppToastType.info:
        return Icons.info;
    }
  }
}
