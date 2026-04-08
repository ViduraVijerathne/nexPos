import 'package:flutter/material.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF36B4AE),
          disabledBackgroundColor: const Color(0xFF36B4AE),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey('label'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
