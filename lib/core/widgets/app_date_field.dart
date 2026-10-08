import 'package:flutter/material.dart';

String formatAppDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? parseAppDate(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    return null;
  }
  final parsed = DateTime.tryParse(normalized);
  // Dart normalizes overflowing dates, such as February 30, into March.
  return parsed != null && formatAppDate(parsed) == normalized ? parsed : null;
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final safeFirstDate = firstDate ?? DateTime(2020);
  final safeLastDate = lastDate ?? DateTime(2100);
  final candidateDate = initialDate ?? now;
  final safeInitialDate = candidateDate.isBefore(safeFirstDate)
      ? safeFirstDate
      : candidateDate.isAfter(safeLastDate)
      ? safeLastDate
      : candidateDate;

  return showDatePicker(
    context: context,
    initialDate: safeInitialDate,
    firstDate: safeFirstDate,
    lastDate: safeLastDate,
    builder: (context, child) {
      final baseTheme = Theme.of(context);
      return Theme(
        data: baseTheme.copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: const Color(0xFF08081A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF111827),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            headerBackgroundColor: Colors.white,
            headerForegroundColor: const Color(0xFF111827),
            headerHeadlineStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            headerHelpStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A94A6),
            ),
            weekdayStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6D6F83),
            ),
            dayStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF171717),
            ),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFFB5B9C5);
              }
              return const Color(0xFF171717);
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF08081A);
              }
              return Colors.transparent;
            }),
            todayForegroundColor: const WidgetStatePropertyAll(
              Color(0xFF111827),
            ),
            todayBackgroundColor: const WidgetStatePropertyAll(
              Colors.transparent,
            ),
            todayBorder: const BorderSide(color: Color(0xFF08081A), width: 1.2),
            yearStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            yearForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return const Color(0xFF171717);
            }),
            yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF08081A);
              }
              return Colors.transparent;
            }),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: const Color(0xFF66758B),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: const Color(0xFF36B4AE),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.decoration,
    this.onChanged,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.initialDate,
  });

  final TextEditingController controller;
  final String hintText;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: parseAppDate(controller.text) ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected == null) {
      return;
    }

    final formatted = formatAppDate(selected);
    controller.text = formatted;
    onChanged?.call(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: true,
      showCursor: false,
      onTap: () => _pickDate(context),
      decoration: decoration.copyWith(
        hintText: hintText,
        suffixIcon: const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: Color(0xFF95A2B5),
        ),
      ),
    );
  }
}
