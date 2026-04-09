import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/settings/services/app_settings_service.dart';
import '../../features/setup/services/setup_service.dart';
import '../theme/app_colors.dart';

class ReportHeaderPreviewCard extends StatelessWidget {
  const ReportHeaderPreviewCard({
    super.key,
    required this.shopInfo,
    required this.settings,
    required this.fromDateLabel,
    required this.toDateLabel,
  });

  final ShopInfo shopInfo;
  final ReportHeaderSettings settings;
  final String fromDateLabel;
  final String toDateLabel;

  bool get _isSinhala => settings.language == InvoiceLanguage.sinhala;

  String _t(String english, String sinhala) => _isSinhala ? sinhala : english;

  TextStyle _style({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = const Color(0xFF334156),
  }) {
    final family = _isSinhala
        ? settings.sinhalaFontFamily
        : settings.englishFontFamily;
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFamily: family.trim().isEmpty ? null : family,
      fontFamilyFallback: _isSinhala
          ? const ['Noto Sans Sinhala', 'Iskoola Pota', 'Nirmala UI']
          : const ['Helvetica', 'Arial', 'Times New Roman', 'Courier New'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = settings.title.trim().isEmpty
        ? (shopInfo.shopName.trim().isEmpty
              ? 'Reports & Analytics'
              : shopInfo.shopName)
        : settings.title.trim();
    final subtitle = settings.subtitle.trim().isEmpty
        ? _t(
            'Comprehensive business reports with real-time data.',
            'ව්‍යාපාර වාර්තා සහ විශ්ලේෂණ තත්‍ය කාලීන දත්ත සමඟ.',
          )
        : settings.subtitle.trim();

    return Container(
      width: 620,
      padding: EdgeInsets.fromLTRB(
        18,
        18 + settings.marginTop,
        18,
        18 + settings.marginBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.showLogo &&
                    shopInfo.logoPath.trim().isNotEmpty &&
                    File(shopInfo.logoPath).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(shopInfo.logoPath),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _style(size: 22, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: _style(
                          size: 13.5,
                          weight: FontWeight.w500,
                          color: const Color(0xFF8492A6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EDF5)),
            ),
            child: Text(
              '$fromDateLabel  -  $toDateLabel',
              style: _style(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
