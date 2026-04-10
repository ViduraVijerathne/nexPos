import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFF),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4FDFF),
                      Color(0xFFE6FAFF),
                      Color(0xFFF7F8FF),
                    ],
                  ),
                ),
              ),
              CustomPaint(painter: _FluidBackdropPainter(progress: value)),
              Positioned(
                left: size.width * 0.08,
                top: 90 + math.sin(value * math.pi * 2) * 18,
                child: _GlowOrb(
                  size: 180,
                  colors: const [Color(0x5538E0D0), Color(0x114299E1)],
                ),
              ),
              Positioned(
                right: size.width * 0.1,
                bottom: 120 + math.cos(value * math.pi * 2) * 24,
                child: _GlowOrb(
                  size: 220,
                  colors: const [Color(0x3338B2AC), Color(0x557C3AED)],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, math.sin(value * math.pi * 2) * 10),
                      child: Transform.scale(
                        scale: 0.985 + (math.sin(value * math.pi * 2) * 0.02),
                        child: Container(
                          width: 184,
                          height: 184,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(46),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x3338B2AC),
                                blurRadius: 42,
                                spreadRadius: 8,
                                offset: Offset(
                                  0,
                                  18 + math.cos(value * math.pi * 2) * 6,
                                ),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(46),
                            child: Image.asset(
                              'assets/branding/nexpos_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF1D9E98), Color(0xFF4F73EE)],
                      ).createShader(bounds),
                      child: const Text(
                        'NexPos',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Flow faster. Sell smarter.',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D7C93),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LoadingPulse(progress: value),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FluidBackdropPainter extends CustomPainter {
  const _FluidBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paintA = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x3338D6C9), Color(0x1138B2AC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final paintB = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x224299E1), Color(0x225C6CF2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final topPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..cubicTo(
        size.width * 0.2,
        size.height * (0.12 + math.sin(progress * math.pi * 2) * 0.02),
        size.width * 0.55,
        size.height * (0.3 + math.cos(progress * math.pi * 2) * 0.03),
        size.width,
        size.height * 0.16,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final bottomPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.22,
        size.height * (0.73 + math.cos(progress * math.pi * 2) * 0.025),
        size.width * 0.7,
        size.height * (0.93 + math.sin(progress * math.pi * 2) * 0.02),
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(topPath, paintA);
    canvas.drawPath(bottomPath, paintB);
  }

  @override
  bool shouldRepaint(covariant _FluidBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _LoadingPulse extends StatelessWidget {
  const _LoadingPulse({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (index) {
        final phase = ((progress * 3) - index).clamp(0.0, 1.0);
        final active = 0.45 + (phase * 0.55);
        return Container(
          width: 12,
          height: 12,
          margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0x2238B2AC),
              const Color(0xFF38B2AC),
              active,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0x2238B2AC),
                blurRadius: 10 * active,
                spreadRadius: 1.2 * active,
              ),
            ],
          ),
        );
      }),
    );
  }
}
