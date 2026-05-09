import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/setup/services/setup_service.dart';
import '../widgets/invoice_preview.dart';

class KotPrintService {
  KotPrintService._();

  static Future<void> printKot({
    required ShopInfo shopInfo,
    required InvoicePreviewData preview,
    Printer? printer,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.all(14),
        build: (_) => _buildKot(shopInfo: shopInfo, preview: preview),
      ),
    );

    await _printDocument(
      bytesBuilder: document.save,
      printer: printer,
      name: 'kot_${preview.invoiceNumber}',
    );
  }

  static Future<void> _printDocument({
    required Future<Uint8List> Function() bytesBuilder,
    required String name,
    Printer? printer,
  }) async {
    if (printer != null) {
      await Printing.directPrintPdf(
        printer: printer,
        name: name,
        onLayout: (_) => bytesBuilder(),
      );
      return;
    }

    await Printing.layoutPdf(name: name, onLayout: (_) => bytesBuilder());
  }

  static pw.Widget _buildKot({
    required ShopInfo shopInfo,
    required InvoicePreviewData preview,
  }) {
    pw.TextStyle style({
      double size = 10.5,
      pw.FontWeight weight = pw.FontWeight.normal,
    }) => pw.TextStyle(fontSize: size, fontWeight: weight);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            shopInfo.shopName.trim().isEmpty
                ? 'Your Shop Name'
                : shopInfo.shopName,
            textAlign: pw.TextAlign.center,
            style: style(size: 16, weight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Kitchen Order Ticket',
            textAlign: pw.TextAlign.center,
            style: style(size: 14, weight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        _infoRow('Invoice', preview.invoiceNumber, style),
        _infoRow('Date', preview.dateTimeText, style),
        _infoRow('Customer', preview.customerName, style),
        if (preview.customerMobile.trim().isNotEmpty)
          _infoRow('Mobile', preview.customerMobile, style),
        _infoRow('Payment', preview.paymentMethod, style),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Item',
                style: style(size: 11, weight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('Qty', style: style(size: 11, weight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 6),
        ...preview.items.asMap().entries.expand((entry) {
          final item = entry.value;
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${entry.key + 1}. ${item.name}',
                    style: style(size: 10.5, weight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  '${item.quantity}',
                  style: style(size: 10.5, weight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
          ];
        }),
        pw.SizedBox(height: 4),
        _infoRow('Items Count', '${preview.items.length}', style),
        _infoRow(
          'Grand Total',
          'Rs ${preview.total.toStringAsFixed(2)}',
          style,
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'Prepare order and serve promptly',
            textAlign: pw.TextAlign.center,
            style: style(size: 10, weight: pw.FontWeight.bold),
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
          pw.SizedBox(width: 8),
          pw.Text(value, style: style(size: 10.5)),
        ],
      ),
    );
  }
}
