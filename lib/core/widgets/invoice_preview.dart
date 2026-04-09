import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/settings/services/app_settings_service.dart';
import '../../features/setup/services/setup_service.dart';
import '../theme/app_colors.dart';

class InvoicePreviewData {
  const InvoicePreviewData({
    required this.invoiceNumber,
    required this.customerName,
    required this.customerMobile,
    required this.dateTimeText,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.paidAmount,
    required this.balance,
  });

  final String invoiceNumber;
  final String customerName;
  final String customerMobile;
  final String dateTimeText;
  final List<InvoicePreviewLine> items;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final double paidAmount;
  final double balance;
}

class InvoicePreviewLine {
  const InvoicePreviewLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

class InvoicePreviewCard extends StatelessWidget {
  const InvoicePreviewCard({
    super.key,
    required this.shopInfo,
    required this.settings,
    required this.preview,
  });

  final ShopInfo shopInfo;
  final InvoiceLayoutSettings settings;
  final InvoicePreviewData preview;

  bool get _isSinhala => settings.language == InvoiceLanguage.sinhala;

  TextStyle _style({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color color = const Color(0xFF111111),
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
      height: 1.2,
    );
  }

  String _t(String english, String sinhala) => _isSinhala ? sinhala : english;

  @override
  Widget build(BuildContext context) {
    final width = settings.paperSize == InvoicePaperSize.thermal80mm
        ? 300.0
        : 520.0;

    return Container(
      width: width,
      color: AppColors.white,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          settings.marginLeft,
          settings.marginTop,
          settings.marginRight,
          settings.marginBottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: const Color(0xFFDDE5EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shopInfo.logoPath.trim().isNotEmpty &&
                File(shopInfo.logoPath).existsSync()) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(shopInfo.logoPath),
                    width: settings.paperSize == InvoicePaperSize.thermal80mm
                        ? 54
                        : 72,
                    height: settings.paperSize == InvoicePaperSize.thermal80mm
                        ? 54
                        : 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Center(
              child: Text(
                shopInfo.shopName.trim().isEmpty
                    ? 'Your Shop Name'
                    : shopInfo.shopName,
                textAlign: TextAlign.center,
                style: _style(
                  size: settings.paperSize == InvoicePaperSize.thermal80mm
                      ? 18
                      : 22,
                  weight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (shopInfo.address.trim().isNotEmpty) shopInfo.address.trim(),
                if (shopInfo.contactNumber.trim().isNotEmpty)
                  shopInfo.contactNumber.trim(),
                if (shopInfo.contactEmail.trim().isNotEmpty)
                  shopInfo.contactEmail.trim(),
              ].join('\n'),
              textAlign: TextAlign.center,
              style: _style(size: 11, weight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF888888)),
            const SizedBox(height: 10),
            _infoRow(_t('Invoice', 'බිල්පත'), preview.invoiceNumber),
            _infoRow(_t('Date', 'දිනය'), preview.dateTimeText),
            const SizedBox(height: 4),
            Text(
              '${_t('Customer', 'පාරිභෝගිකයා')}: ${preview.customerName}',
              style: _style(size: 11, weight: FontWeight.w700),
            ),
            if (preview.customerMobile.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${_t('Mobile', 'දුරකථන')}: ${preview.customerMobile}',
                style: _style(size: 11),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF888888)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    _t('Item / Qty x Price', 'භාණ්ඩය / ප්‍රමාණය x මිල'),
                    style: _style(size: 10.5, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _t('Amount', 'මුදල'),
                  style: _style(size: 10.5, weight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < preview.items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${i + 1}. ${preview.items[i].name}',
                          style: _style(size: 11, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${preview.items[i].quantity} x ${preview.items[i].unitPrice.toStringAsFixed(2)}',
                          style: _style(size: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    preview.items[i].subtotal.toStringAsFixed(2),
                    style: _style(size: 11, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE7EBF0)),
              const SizedBox(height: 8),
            ],
            _summaryRow(
              _t('No of items', 'භාණ්ඩ ගණන'),
              '${preview.items.length}',
            ),
            _summaryRow(
              _t('Subtotal', 'උප එකතුව'),
              'Rs ${preview.subtotal.toStringAsFixed(2)}',
            ),
            if (preview.tax > 0)
              _summaryRow(
                _t('Tax', 'බදු'),
                'Rs ${preview.tax.toStringAsFixed(2)}',
              ),
            _summaryRow(
              _t('Grand Total', 'මුළු එකතුව'),
              'Rs ${preview.total.toStringAsFixed(2)}',
              emphasize: true,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFF555555), thickness: 1),
            const SizedBox(height: 8),
            _summaryRow(
              '${preview.paymentMethod} (${preview.dateTimeText.split(' ').first})',
              'Rs ${preview.paidAmount.toStringAsFixed(2)}',
            ),
            _summaryRow(
              _t('Balance', 'ඉතිරි මුදල'),
              'Rs ${preview.balance.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                _t(
                  'Thank you. Please come again.',
                  'ස්තුතියි. නැවත පැමිණෙන්න.',
                ),
                textAlign: TextAlign.center,
                style: _style(size: 11, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _style(size: 11, weight: FontWeight.w700),
            ),
          ),
          Text(value, style: _style(size: 11)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _style(
                size: emphasize ? 12.5 : 11,
                weight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: _style(
              size: emphasize ? 13 : 11,
              weight: emphasize ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class InvoicePrintPreviewDialog extends StatelessWidget {
  const InvoicePrintPreviewDialog({
    super.key,
    required this.shopInfo,
    required this.settings,
    required this.preview,
    required this.onPrint,
  });

  final ShopInfo shopInfo;
  final InvoiceLayoutSettings settings;
  final InvoicePreviewData preview;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: settings.paperSize == InvoicePaperSize.thermal80mm ? 420 : 760,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9FC),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Invoice Print Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3A4D),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Center(
                  child: InvoicePreviewCard(
                    shopInfo: shopInfo,
                    settings: settings,
                    preview: preview,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print Invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
