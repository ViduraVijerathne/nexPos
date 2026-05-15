import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/settings/services/app_settings_service.dart';
import '../../features/setup/services/setup_service.dart';
import '../widgets/invoice_preview.dart';

class InvoicePrintService {
  InvoicePrintService._();

  static Future<void> printInvoice({
    required ShopInfo shopInfo,
    required InvoiceLayoutSettings settings,
    required InvoicePreviewData preview,
    Printer? printer,
  }) async {
    final document = pw.Document();
    final logo = await _loadLogo(shopInfo.logoPath);

    document.addPage(
      pw.Page(
        pageFormat: _pageFormat(settings),
        margin: pw.EdgeInsets.fromLTRB(
          settings.marginLeft,
          settings.marginTop,
          settings.marginRight,
          settings.marginBottom,
        ),
        build: (context) => _buildInvoiceDocument(
          shopInfo: shopInfo,
          settings: settings,
          preview: preview,
          logo: logo,
        ),
      ),
    );

    if (printer != null) {
      await Printing.directPrintPdf(
        printer: printer,
        name: preview.invoiceNumber,
        onLayout: (_) async => document.save(),
      );
      return;
    }

    await Printing.layoutPdf(
      name: preview.invoiceNumber,
      onLayout: (_) async => document.save(),
    );
  }

  static Future<Uint8List?> _loadLogo(String path) async {
    if (path.trim().isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  static PdfPageFormat _pageFormat(InvoiceLayoutSettings settings) {
    if (settings.paperSize == InvoicePaperSize.thermal80mm) {
      return PdfPageFormat(80 * PdfPageFormat.mm, double.infinity);
    }
    return PdfPageFormat.a4;
  }

  static pw.Widget _buildInvoiceDocument({
    required ShopInfo shopInfo,
    required InvoiceLayoutSettings settings,
    required InvoicePreviewData preview,
    required Uint8List? logo,
  }) {
    final isSinhala = settings.language == InvoiceLanguage.sinhala;
    String t(String english, String sinhala) => isSinhala ? sinhala : english;

    pw.TextStyle style({
      double size = 11,
      pw.FontWeight weight = pw.FontWeight.normal,
    }) => pw.TextStyle(fontSize: size, fontWeight: weight);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (logo != null) ...[
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(logo),
              width: settings.paperSize == InvoicePaperSize.thermal80mm
                  ? 44
                  : 62,
              height: settings.paperSize == InvoicePaperSize.thermal80mm
                  ? 44
                  : 62,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Center(
          child: pw.Text(
            shopInfo.shopName.trim().isEmpty
                ? 'Your Shop Name'
                : shopInfo.shopName,
            textAlign: pw.TextAlign.center,
            style: style(
              size: settings.paperSize == InvoicePaperSize.thermal80mm
                  ? 18
                  : 22,
              weight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          [
            if (shopInfo.address.trim().isNotEmpty) shopInfo.address.trim(),
            if (shopInfo.contactNumber.trim().isNotEmpty)
              shopInfo.contactNumber.trim(),
            if (shopInfo.contactEmail.trim().isNotEmpty)
              shopInfo.contactEmail.trim(),
          ].join('\n'),
          textAlign: pw.TextAlign.center,
          style: style(size: 10),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        _infoRow(t('Invoice', 'බිල්පත'), preview.invoiceNumber, style),
        _infoRow(t('Date', 'දිනය'), preview.dateTimeText, style),
        pw.SizedBox(height: 4),
        pw.Text(
          '${t('Customer', 'පාරිභෝගිකයා')}: ${preview.customerName}',
          style: style(size: 10.5, weight: pw.FontWeight.bold),
        ),
        if (preview.customerMobile.trim().isNotEmpty)
          pw.Text(
            '${t('Mobile', 'දුරකථන')}: ${preview.customerMobile}',
            style: style(size: 10.5),
          ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                t('Item / Qty x Price', 'භාණ්ඩය / ප්‍රමාණය x මිල'),
                style: style(size: 10, weight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              t('Amount', 'මුදල'),
              style: style(size: 10, weight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        ...preview.items.asMap().entries.expand((entry) {
          final index = entry.key;
          final item = entry.value;
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '#${index + 1}. ${item.name}',
                        style: style(size: 10.5, weight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}',
                        style: style(size: 10),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  item.subtotal.toStringAsFixed(2),
                  style: style(size: 10.5, weight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
          ];
        }),
        _summaryRow(
          t('No of items', 'භාණ්ඩ ගණන'),
          '${preview.items.length}',
          style,
        ),
        _summaryRow(
          t('Subtotal', 'උප එකතුව'),
          'Rs ${preview.subtotal.toStringAsFixed(2)}',
          style,
        ),
        if (preview.discount > 0)
          _summaryRow(
            t('Discount', 'වට්ටම'),
            '-Rs ${preview.discount.toStringAsFixed(2)}',
            style,
          ),
        if (preview.tax > 0)
          _summaryRow(
            t('Tax', 'බදු'),
            'Rs ${preview.tax.toStringAsFixed(2)}',
            style,
          ),
        _summaryRow(
          t('Grand Total', 'මුළු එකතුව'),
          'Rs ${preview.total.toStringAsFixed(2)}',
          style,
          emphasize: true,
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 6),
        _summaryRow(
          '${preview.paymentMethod} (${preview.dateTimeText.split(' ').first})',
          'Rs ${preview.paidAmount.toStringAsFixed(2)}',
          style,
        ),
        _summaryRow(
          t('Balance', 'ඉතිරි මුදල'),
          'Rs ${preview.balance.toStringAsFixed(2)}',
          style,
        ),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(
            t('Thank you. Please come again.', 'ස්තුතියි. නැවත පැමිණෙන්න.'),
            textAlign: pw.TextAlign.center,
            style: style(size: 10.5, weight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoRow(
    String label,
    String value,
    pw.TextStyle Function({double size, pw.FontWeight weight}) style,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: style(size: 10.5, weight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(value, style: style(size: 10.5)),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value,
    pw.TextStyle Function({double size, pw.FontWeight weight}) style, {
    bool emphasize = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: style(
                size: emphasize ? 12 : 10.5,
                weight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: style(
              size: emphasize ? 12.5 : 10.5,
              weight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
