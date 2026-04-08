import 'package:flutter/material.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7EDF5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE8FBF7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF36B4AE), size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334156),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8592A6),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: const Text(
                'This is a placeholder page so the dashboard navigation already works with separate files. We can replace it with the full module next.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A687D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
