import 'package:flutter/material.dart';

class PinNumberPad extends StatelessWidget {
  const PinNumberPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((value) {
              if (value.isEmpty) {
                return const SizedBox(width: 78);
              }

              final isBack = value == 'back';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  onTap: !enabled
                      ? null
                      : () {
                          if (isBack) {
                            onBackspace();
                          } else {
                            onDigitPressed(value);
                          }
                        },
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    width: 66,
                    height: 58,
                    decoration: BoxDecoration(
                      color: enabled ? Colors.white : const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4EAF2)),
                    ),
                    child: Center(
                      child: isBack
                          ? const Icon(
                              Icons.backspace_outlined,
                              color: Color(0xFF64748B),
                            )
                          : Text(
                              value,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: enabled
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFB0BBCB),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
