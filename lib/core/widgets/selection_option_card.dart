import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SelectionOptionCard<T> extends StatelessWidget {
  const SelectionOptionCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.description,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  final T value;
  final T? groupValue;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled
              ? (isSelected ? AppColors.primaryLight : Colors.white)
              : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : const Color(0xFFE4EAF2),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: enabled ? (_) => onTap() : null,
              activeColor: AppColors.primaryTeal,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF334155)
                          : const Color(0xFF9AA8BC),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? const Color(0xFF7F8DA1)
                          : const Color(0xFFB1BDCD),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
