import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.autofocus = false,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5E6B80),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          autofocus: autofocus,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: const Color(0xFF445065),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: const Color(0xFFA0AEC0),
              fontWeight: FontWeight.w500,
            ),
            errorStyle: textTheme.bodySmall?.copyWith(height: 1.1),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFB4BDC9), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF56565)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF56565), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
