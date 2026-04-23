import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/dashboard/models/models.dart';

class LabelPrintService {
  LabelPrintService._();

  static Future<void> printLabels({
    required LabelPrinterItem item,
    required int quantity,
  }) async {
    final document = pw.Document();

    for (var index = 0; index < quantity; index++) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            62 * PdfPageFormat.mm,
            38 * PdfPageFormat.mm,
          ),
          margin: const pw.EdgeInsets.all(8),
          build: (_) => _buildLabel(item),
        ),
      );
    }

    await Printing.layoutPdf(
      name: 'label_${item.barcode}',
      onLayout: (_) async => document.save(),
    );
  }

  static pw.Widget _buildLabel(LabelPrinterItem item) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            item.title,
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            item.secondaryText,
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: const pw.TextStyle(fontSize: 6.8),
          ),
          pw.Spacer(),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: item.barcode,
            height: 32,
            drawText: false,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            item.barcode,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
