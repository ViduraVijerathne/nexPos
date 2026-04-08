import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_toast.dart';

class AppToastOverlay extends StatelessWidget {
  const AppToastOverlay({super.key, required this.child});

  final Widget child;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 20,
          right: 20,
          child: SafeArea(
            child: ValueListenableBuilder<List<AppToastData>>(
              valueListenable: AppToast.listenable,
              builder: (context, toasts, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final toast in toasts) ...[
                      _ToastCard(key: ValueKey(toast.id), toast: toast),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.toast});

  final AppToastData toast;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.toast.duration,
    )..forward();

    _progressAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        AppToast.dismiss(widget.toast.id);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.toast.type.accentColor;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.topRight,
          child: child,
        );
      },
      child: SizedBox(
        width: 360,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1A1E),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 22,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(
                        widget.toast.type.icon,
                        color: accentColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.toast.message,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => AppToast.dismiss(widget.toast.id),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFFE6E6E6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progressAnimation.value,
                        child: Container(height: 4, color: accentColor),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
